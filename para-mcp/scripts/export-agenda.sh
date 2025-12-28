#!/bin/bash
#
# Para Org-Agenda Export Script
# Generates org-mode agenda view from Para projects/areas
#
# Usage: export-agenda.sh [options]
#   --days N            Number of days in agenda (default: 7)
#   --project NAME      Limit to specific project
#   --area NAME         Limit to specific area
#   --scope SCOPE       Scope: projects, areas, or all (default: all)
#   --format FORMAT     Output format: json or text (default: json)
#   --stdout            Output to STDOUT
#

# Default values
DAYS=7
SCOPE="all"
FORMAT="json"
PROJECT=""
AREA=""
PARA_HOME="${PARA_HOME:-$HOME/Dropbox/para}"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --days)
      DAYS="$2"
      shift 2
      ;;
    --project)
      PROJECT="$2"
      SCOPE="project"
      shift 2
      ;;
    --area)
      AREA="$2"
      SCOPE="area"
      shift 2
      ;;
    --scope)
      SCOPE="$2"
      shift 2
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --stdout)
      # Always output to stdout (this is the default)
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Check if emacs is available
if ! command -v emacs &> /dev/null; then
  echo "Error: emacs not found in PATH" >&2
  exit 1
fi

# Create temp file for elisp script
ELISP_SCRIPT=$(mktemp /tmp/para-agenda.XXXXXX.el)

# Build org-agenda-files list based on scope
ORG_FILES_ELISP=""
case "$SCOPE" in
  project)
    if [[ -z "$PROJECT" ]]; then
      echo "Error: --project requires a project name" >&2
      exit 1
    fi
    ORG_FILES_ELISP="(setq org-agenda-files (list \"$PARA_HOME/projects/$PROJECT/journal.org\"))"
    ;;
  area)
    if [[ -z "$AREA" ]]; then
      echo "Error: --area requires an area name" >&2
      exit 1
    fi
    ORG_FILES_ELISP="(setq org-agenda-files (list \"$PARA_HOME/areas/$AREA/journal.org\"))"
    ;;
  projects)
    ORG_FILES_ELISP="(setq org-agenda-files
      (split-string (shell-command-to-string \"find $PARA_HOME/projects -type f -name '*.org' -not -ipath '*scapple*'\") \"\\n\" t))"
    ;;
  areas)
    ORG_FILES_ELISP="(setq org-agenda-files
      (split-string (shell-command-to-string \"find $PARA_HOME/areas -type f -name '*.org' -not -ipath '*scapple*'\") \"\\n\" t))"
    ;;
  all|*)
    ORG_FILES_ELISP="(setq org-agenda-files
      (append
       (split-string (shell-command-to-string \"find $PARA_HOME/projects -type f -name '*.org' -not -ipath '*scapple*'\") \"\\n\" t)
       (split-string (shell-command-to-string \"find $PARA_HOME/areas -type f -name '*.org' -not -ipath '*scapple*'\") \"\\n\" t)
       (if (file-exists-p \"$PARA_HOME/resources/dates.org\")
           (list \"$PARA_HOME/resources/dates.org\")
         nil)))"
    ;;
esac

# Write elisp code to generate agenda
cat > "$ELISP_SCRIPT" << ELISP_EOF
(require 'org)
(require 'org-agenda)

;; Set up agenda files
$ORG_FILES_ELISP

;; Set TODO keywords (standard Para configuration)
(setq org-todo-keywords
      '((sequence "TODO(t)" "PROJ(p)" "|" "DONE(d)" "-" "?" "|" "X")
        (sequence "NEXT(n)" "WAIT(w)" "HOLD(h)" "|" "ABRT(c)")))

;; Configure agenda span
(setq org-agenda-span $DAYS)
(setq org-agenda-start-day nil)

;; Generate agenda and write to file
(let ((txt-file "/tmp/para-agenda.txt"))
  (org-batch-agenda "a")
  (org-agenda-write txt-file))
ELISP_EOF

# Execute emacs in batch mode
cd "$HOME" && emacs --batch \
  --load "$HOME/.emacs.d/init.el" \
  --load "$ELISP_SCRIPT" \
  >/dev/null 2>&1

# Check if emacs execution succeeded
if [[ $? -ne 0 ]]; then
  echo "Error: Emacs agenda generation failed" >&2
  rm "$ELISP_SCRIPT"
  exit 1
fi

# Cleanup temp script
rm "$ELISP_SCRIPT"

# Check if output file exists
if [[ ! -f /tmp/para-agenda.txt ]]; then
  echo "Error: Agenda file not created" >&2
  exit 1
fi

# Output based on format
if [[ "$FORMAT" == "json" ]]; then
  # Convert to JSON
  AGENDA_TEXT=$(cat /tmp/para-agenda.txt)

  # Simple JSON output with escaped text
  jq -n --arg agenda "$AGENDA_TEXT" \
    --arg scope "$SCOPE" \
    --argjson days $DAYS \
    '{
      scope: $scope,
      days: $days,
      agenda: $agenda
    }'
else
  # Plain text output
  cat /tmp/para-agenda.txt
fi

# Cleanup
rm -f /tmp/para-agenda.txt
