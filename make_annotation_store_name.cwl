
#!/usr/bin/env cwl-runner
#
# Appends "submission-" to annotation store name
#

$namespaces:
  s: https://schema.org/

s:author:
  - class: s:Person
    s:identifier: https://orcid.org/0000-0002-5841-0198
    s:email: thomas.yu@sagebionetworks.org
    s:name: Thomas Yu

cwlVersion: v1.0
class: ExpressionTool

requirements:
  - class: InlineJavascriptRequirement

inputs:
  - id: submission_id
    type: int

outputs:
  - id: annotation_store_id
    type: string

expression: |

  ${
    return {annotation_store_id: "submission-" + inputs.submission_id};
  }
  