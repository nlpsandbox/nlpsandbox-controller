#!/usr/bin/env cwl-runner
#
# Maps evaluation id to annotator type
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

inputs:
  - id: queue
    type: string

outputs:
  - id: annotator_type
    type: string

requirements:
  - class: InlineJavascriptRequirement

expression: |

  ${
    if(inputs.queue == "9614658" || inputs.queue == "9614684"){
      return {annotator_type: "nlpsandbox:physical-address-annotator"};
    } else if (inputs.queue == "9614652" || inputs.queue == "9614654"){
      return {annotator_type: "nlpsandbox:date-annotator"};
    } else if (inputs.queue == "9614657" || inputs.queue == "9614685"){
      return {annotator_type: "nlpsandbox:person-name-annotator"};
    } else {
      throw 'invalid queue';
    }
  }