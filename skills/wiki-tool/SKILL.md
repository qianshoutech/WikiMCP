---
name: wiki-tool
description: Access internal Confluence Wiki documentation. Use this Skill when users mention wiki.p1.cn, internal docs, company Wiki, knowledge base, or need to search/view internal company documentation.
allowed-tools: Read, Grep, Glob, Bash
---

# Wiki Documentation Tool

This Skill provides access to the internal Confluence Wiki (wiki.p1.cn).

## File Locations

All files are located in this Skill directory (same directory as SKILL.md):

- Main script: `wikicli.py`
- Config file: `env`
- Dependencies: `requirements.txt`

## Environment Configuration

Cookie is configured in the `env` file, load it using the `source` command before use.

### First Time Setup

Install Python dependencies before first use:

```bash
pip3 install -r {SKILL_DIR}/requirements.txt
```

## Command Usage

**Note**: In the following commands, `{SKILL_DIR}` refers to the path of this SKILL.md directory.

### 1. Convert Wiki Page to Markdown

```bash
# Load config and convert by URL
source {SKILL_DIR}/env && python3 {SKILL_DIR}/wikicli.py convert "https://wiki.p1.cn/pages/viewpage.action?pageId=12345"

# Convert by page ID
source {SKILL_DIR}/env && python3 {SKILL_DIR}/wikicli.py convert --page-id 12345
```

### 2. Search Wiki Content

```bash
# Basic search
source {SKILL_DIR}/env && python3 {SKILL_DIR}/wikicli.py search "keyword"

# Search with parameters
source {SKILL_DIR}/env && python3 {SKILL_DIR}/wikicli.py search --query "API docs" --limit 20
```

## Workflow

### When User Sends a Wiki Link

1. Use the `convert` command to get page content
2. Interpret and summarize key information for the user

### When User Needs to Find Information

1. First use the `search` command to find relevant content
2. Display search results for user selection
3. After user confirmation, use `convert` to get detailed content

## Output Description

### convert Command Output

- Markdown file path
- Output directory path
- Number of downloaded images
- Complete Markdown content

### search Command Output

- Total number of search results
- Each result includes: title, author, last modified time, excerpt, URL

## Notes

1. **Cookie Validity**: Cookie may expire, prompt user to update Cookie if requests fail
2. **Network Dependency**: Requires network access to wiki.p1.cn
3. **Image Download**: convert command automatically downloads page images locally
4. **Search Limit**: Search results return maximum 50 items
5. **Python Dependencies**: Requires Python 3.8+ and requests, beautifulsoup4, lxml libraries

## Troubleshooting

### Request Failed

- Check if WIKI_COOKIE environment variable is set
- Check if Cookie has expired
- Check network connection

### Content Not Found

- Try different search keywords
- Verify URL or page ID is correct

### Dependency Issues

If missing module errors occur, run:

```bash
pip3 install -r {SKILL_DIR}/requirements.txt
```
