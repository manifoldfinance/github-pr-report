#!/bin/bash

source .env

# Set the GraphQL query with double quotes to allow variable expansion
QUERY="
{ \
  \"query\": \"query {\
    repository(owner: \\\"$OWNER_NAME\\\", name: \\\"$REPO_NAME\\\") {\
      issues(\
        last: 45,\
        states: [CLOSED]\
      ) {\
        edges {\
          node {\
            number\
            title\
            body\
            url\
            createdAt\
            comments(last: 10){\
                edges {\
                    node {\
                        body\
                    }\
                }\
            }\
          }\
        }\
      }\
    }\
  }\"\
}\
"

echo "GraphQL Query:"
echo "$QUERY"

# Make the API request using curl and store the response in a file
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$QUERY" https://api.github.com/graphql > response-issues.json

# Parse the JSON response using jq and create a Markdown report
echo "# Issues Report" > report-issues.md
echo "" >> report-issues.md

cat response-issues.json | jq -r '
  .data.repository.issues.edges[] | 
  "## Issue #" + (.node.number | tostring) + ": " + .node.title + "\n" +
  "- Created: " + .node.createdAt + "\n" +
  "### Issue Body:\n" + .node.body + "\n" +
  "- Issue URL: " + .node.url + "\n"
' >> report-issues.md

# Optionally, you can remove the response file after processing
# rm response-issues.json
