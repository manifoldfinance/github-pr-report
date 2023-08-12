#!/bin/bash

source .env

# Set the GraphQL query with double quotes to allow variable expansion
QUERY="
{ \
  \"query\": \"query {\
    repository(owner: \\\"$OWNER_NAME\\\", name: \\\"$REPO_NAME\\\") {\
      pullRequests(\
        last: 45,\
        states: [MERGED]\
      ) {\
        edges {\
          node {\
            number\
            title\
            state\
            createdAt\
            mergedAt\
            closingIssuesReferences(last: 5){\
                edges {\
                    node {\
                        title\
                    }\
                }\
            }\
            comments(last: 10){\
                edges {\
                    node {\
                        body\
                    }\
                }\
            }\
            files(last: 10) {\
                nodes {\
                    path\
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
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$QUERY" https://api.github.com/graphql > response.json

# Parse the JSON response using jq and create a Markdown report
echo "# Pull Requests Report" > report.md
echo "" >> report.md

cat response.json | jq -r '
  .data.repository.pullRequests.edges[] | 
  "## PR #" + (.node.number | tostring) + ": " + .node.title + "\n" +
  "- State: " + .node.state + "\n" +
  "- Created: " + .node.createdAt + "\n" +
  "- Merged: " + .node.mergedAt + "\n" +
"- Linked Issues: " + 
  (if .node.closingIssuesReferences.edges | length > 0 then
    (.node.closingIssuesReferences.edges | 
      map("- #" + .node.title) | join(", "))
  else
    "None"
  end) + "\n" +
  "- Comments: " +
  (if .node.comments.edges | length > 0 then
    (.node.comments.edges | 
      map("- " + .node.body) | join("\n")) 
  else
    "None"
  end) + "\n"
' >> report.md

# Optionally, you can remove the response file after processing
# rm response.json
