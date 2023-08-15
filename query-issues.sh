#!/bin/bash

source .env

# Set the GraphQL query with double quotes to allow variable expansion
QUERY="
{ \
  \"query\": \"query {\
    repository(owner: \\\"$OWNER_NAME\\\", name: \\\"$REPO_NAME\\\") {\
      issues(\
        last: 20,\
        states: [CLOSED]\
      ) {\
        edges {\
          node {\
            title\
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
                                body\
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
                                    edges {\
                                        node {\
                                            path\
                                        }\
                                    }\
                                }\
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
  "## Issue: " + .node.title + "\n" +
  "### Created: " + .node.createdAt + "\n" +
  "### URL: " + .node.url + "\n" +
  "### Comments: " +
  (if .node.comments.edges | length > 0 then
    (.node.comments.edges |
      map("- " + .node.body) | join("\n")) 
  else
    "None"
  end) + "\n" +
  "### Timeline Items: " + "\n" +
  (if .node.timelineItems.nodes | length > 0 then
    (.node.timelineItems.nodes |
      map(
        select(.closer != null) |   # Filter out events with null closer
        " - Closer Pull Request #" + (.closer.number | tostring) + ": " + .closer.title + "\n" +
        " - URL: " + .closer.url + "\n" +
        " - Body: " + .closer.body + "\n" +
        " - Closing Issues: " + 
        (if .closer.closingIssuesReferences.edges | length > 0 then
          (.closer.closingIssuesReferences.edges |
            map("- #" + .node.title) | join(", "))
        else
          "None"
        end) + "\n" +
        " - Comments: " +
        (if .closer.comments.edges | length > 0 then
          (.closer.comments.edges |
            map("- " + .node.body) | join("\n")) 
        else
          "None"
        end) + "\n" +
        " - Files: " +
        (if .closer.files.edges | length > 0 then
          (.closer.files.edges |
            map("- " + .node.path) | join("\n"))
        else
          "None"
        end)
      ) | join("\n\n"))
  else
    "None"
  end) + "\n\n"
' >> report-issues.md

# Optionally, you can remove the response file after processing
# rm response-issues.json
