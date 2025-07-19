#!/bin/bash

# Usage: ./parse_lynis.sh /path/to/lynis-report.dat

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

REPORT_FILE="$1"

if [[ ! -f "$REPORT_FILE" ]]; then
  echo -e "${RED}Error: File not found: $REPORT_FILE${NC}"
  exit 1
fi

echo -e "${BOLD}${CYAN}==== Lynis Report Summary ====${NC}"
echo

# Extract suggestions with better formatting
echo -e "${BOLD}${BLUE}=== SUGGESTIONS ===${NC}"
SUGGESTION_COUNT=0
while IFS= read -r line; do
  if [[ $line =~ ^suggestion\[\]=(.*)$ ]]; then
    SUGGESTION_COUNT=$((SUGGESTION_COUNT + 1))
    content="${BASH_REMATCH[1]}"
    IFS='|' read -ra PARTS <<< "$content"
    
    echo -e "${YELLOW}SUGGESTION #$SUGGESTION_COUNT:${NC}"
    echo -e "  ${BOLD}ID:${NC} ${PARTS[0]}"
    echo -e "  ${BOLD}Issue:${NC} ${PARTS[1]}"
    if [[ -n "${PARTS[2]}" && "${PARTS[2]}" != "-" ]]; then
      echo -e "  ${BOLD}Action:${NC} ${GREEN}${PARTS[2]}${NC}"
    fi
    if [[ -n "${PARTS[3]}" && "${PARTS[3]}" != "-" ]]; then
      echo -e "  ${BOLD}Details:${NC} ${PARTS[3]}"
    fi
    
    # Show related details if available
    details=$(grep "^details\[\]=${PARTS[0]}" "$REPORT_FILE" | head -5)
    if [[ -n "$details" ]]; then
      echo -e "  ${BOLD}Configuration Details:${NC}"
      echo "$details" | while IFS= read -r detail_line; do
        if [[ $detail_line =~ ^details\[\]=(.*)$ ]]; then
          detail_content="${BASH_REMATCH[1]}"
          IFS='|' read -ra DETAIL_PARTS <<< "$detail_content"
          echo -e "    - ${CYAN}${DETAIL_PARTS[3]}${NC}: current=${RED}${DETAIL_PARTS[5]}${NC}, recommended=${GREEN}${DETAIL_PARTS[4]}${NC}"
        fi
      done
    fi
    echo
  fi
done < "$REPORT_FILE"

if [[ $SUGGESTION_COUNT -eq 0 ]]; then
  echo -e "${GREEN}No suggestions found.${NC}"
fi
echo

# Extract manual tasks
echo -e "${BOLD}${PURPLE}=== MANUAL TASKS ===${NC}"
MANUAL_COUNT=0
while IFS= read -r line; do
  if [[ $line =~ ^manual\[\]=(.*)$ ]]; then
    MANUAL_COUNT=$((MANUAL_COUNT + 1))
    content="${BASH_REMATCH[1]}"
    echo -e "${YELLOW}MANUAL TASK #$MANUAL_COUNT:${NC} $content"
  fi
done < "$REPORT_FILE"

if [[ $MANUAL_COUNT -eq 0 ]]; then
  echo -e "${GREEN}No manual tasks found.${NC}"
fi
echo

# Optional: Extract installed packages count
PKG_COUNT=$(grep '^installed_packages=' "$REPORT_FILE" | cut -d'=' -f2 | tr -d ' ')
echo -e "${BOLD}${CYAN}Installed Packages Found:${NC} $PKG_COUNT"
echo

# Extract warnings with better formatting (moved to just before final score)
echo -e "${BOLD}${RED}=== WARNINGS ===${NC}"
WARNING_COUNT=0
while IFS= read -r line; do
  if [[ $line =~ ^warning\[\]=(.*)$ ]]; then
    WARNING_COUNT=$((WARNING_COUNT + 1))
    content="${BASH_REMATCH[1]}"
    IFS='|' read -ra PARTS <<< "$content"
    
    echo -e "${RED}WARNING #$WARNING_COUNT:${NC}"
    echo -e "  ${BOLD}ID:${NC} ${PARTS[0]}"
    echo -e "  ${BOLD}Issue:${NC} ${RED}${PARTS[1]}${NC}"
    if [[ -n "${PARTS[2]}" && "${PARTS[2]}" != "-" ]]; then
      echo -e "  ${BOLD}Action:${NC} ${GREEN}${PARTS[2]}${NC}"
    fi
    if [[ -n "${PARTS[3]}" && "${PARTS[3]}" != "-" ]]; then
      echo -e "  ${BOLD}Details:${NC} ${PARTS[3]}"
    fi
    
    # Show related details if available
    details=$(grep "^details\[\]=${PARTS[0]}" "$REPORT_FILE" | head -5)
    if [[ -n "$details" ]]; then
      echo -e "  ${BOLD}Configuration Details:${NC}"
      echo "$details" | while IFS= read -r detail_line; do
        if [[ $detail_line =~ ^details\[\]=(.*)$ ]]; then
          detail_content="${BASH_REMATCH[1]}"
          IFS='|' read -ra DETAIL_PARTS <<< "$detail_content"
          echo -e "    - ${CYAN}${DETAIL_PARTS[3]}${NC}: current=${RED}${DETAIL_PARTS[5]}${NC}, recommended=${GREEN}${DETAIL_PARTS[4]}${NC}"
        fi
      done
    fi
    
    # Show related suggestion if available
    related_suggestion=$(grep "^suggestion\[\]=${PARTS[0]}" "$REPORT_FILE")
    if [[ -n "$related_suggestion" ]]; then
      echo -e "  ${BOLD}Related Suggestion:${NC}"
      echo "$related_suggestion" | while IFS= read -r suggestion_line; do
        if [[ $suggestion_line =~ ^suggestion\[\]=(.*)$ ]]; then
          suggestion_content="${BASH_REMATCH[1]}"
          IFS='|' read -ra SUGGESTION_PARTS <<< "$suggestion_content"
          echo -e "    ${BOLD}Issue:${NC} ${SUGGESTION_PARTS[1]}"
          if [[ -n "${SUGGESTION_PARTS[2]}" && "${SUGGESTION_PARTS[2]}" != "-" ]]; then
            echo -e "    ${BOLD}Action:${NC} ${GREEN}${SUGGESTION_PARTS[2]}${NC}"
          fi
          if [[ -n "${SUGGESTION_PARTS[3]}" && "${SUGGESTION_PARTS[3]}" != "-" ]]; then
            echo -e "    ${BOLD}Details:${NC} ${SUGGESTION_PARTS[3]}"
          fi
        fi
      done
    fi
    echo
  fi
done < "$REPORT_FILE"

if [[ $WARNING_COUNT -eq 0 ]]; then
  echo -e "${GREEN}No warnings found.${NC}"
fi
echo

# Extract hardening index (moved to bottom)
HARDENING_INDEX=$(grep '^hardening_index=' "$REPORT_FILE" | cut -d'=' -f2 | tr -d ' ')

# Color the score based on value
if [[ $HARDENING_INDEX -ge 80 ]]; then
  SCORE_COLOR=$GREEN
elif [[ $HARDENING_INDEX -ge 60 ]]; then
  SCORE_COLOR=$YELLOW
else
  SCORE_COLOR=$RED
fi

echo -e "${BOLD}${WHITE}=== FINAL SCORE ===${NC}"
echo -e "${BOLD}Hardening Index:${NC} ${SCORE_COLOR}$HARDENING_INDEX / 100${NC}"
echo

echo -e "${BOLD}${CYAN}==== End of Report ====${NC}"