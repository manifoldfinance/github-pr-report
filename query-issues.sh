#!/bin/bash

source .env

# Set the GraphQL query with double quotes to allow variable expansion
QUERY="
{ \
  \"query\": \"query {\
    repository(owner: \\\"$OWNER_NAME\\\", name: \\\"$REPO_NAME\\\") {\
      issues(\
        last: 10,\
        states: [CLOSED]\
      ) {\
        edges {\
          node {\
            number\
            title\
            body\
            url\
            createdAt\
            comments(last: 5){\
                edges {\
                    node {\
                        body\
                    }\
                }\
            }\
            timelineItems(last: 5) {\
                nodes {\
                    ... on ClosedEvent {\
                        closer {\
                            ... on PullRequest {\
                                number\
                                title\
                                url\
                            }\
                        }\
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
  "- Comments: " +
  (if .node.comments.edges | length > 0 then
    (.node.comments.edges | 
      map("- " + .node.body) | join("\n")) 
  else
    "None"
  end) + "\n" +
  "- Timeline Items: " +
  (if .node.timelineItems.nodes | length > 0 then
    (.node.timelineItems.nodes |
      map(
        "- Type: ClosedEvent" + "\n" +
        "  Closer Pull Request #" + (.closer.number | tostring) + ": " + .closer.title + .closer.url
      ) | join("\n"))
  else
    "None"
  end) + "\n" +
  "- Issue URL: " + .node.url + "\n"
' >> report-issues.md

# Optionally, you can remove the response file after processing
# rm response-issues.json
