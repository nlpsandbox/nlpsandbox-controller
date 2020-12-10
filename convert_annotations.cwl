#!/usr/bin/env cwl-runner
#
# Convert annotated notes to annotation store annotations
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python

hints:
  DockerRequirement:
    dockerPull: python:3.7

inputs:

  - id: annotation_json
    type: File

arguments:
  - valueFrom: convert_annotations.py
  - valueFrom: $(inputs.annotation_json)
    prefix: -a
  - valueFrom: results.json
    prefix: -r


requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: convert_annotations.py
        entry: |
          #!/usr/bin/env python
          import argparse
          import json
          import os

          parser = argparse.ArgumentParser()
          parser.add_argument("-a", "--annotation_json", required=True, help="Annotation json file")
          parser.add_argument("-r", "--results", required=True, help="Results file")
          args = parser.parse_args()

          with open(args.annotation_json, "r") as annote_f:
              annotations = json.load(annote_f)

          annotation_key = "date_annotations"
          post_path = "textDateAnnotations"

          all_annotations = []
          for annotation in annotations:
              # print(annotation)
              noteid = annotation['annotationSource']['resourceSource']['name']
              for annots in annotation[post_path]:
                  annots['noteId'] = os.path.basename(noteid)
                  all_annotations.append(annots)

          new_annotations = {annotation_key: all_annotations}
          # print(new_annotations)
          with open(args.results, "w") as results_f:
              json.dump(new_annotations, results_f)

     
outputs:

  - id: results
    type: File
    outputBinding:
      glob: results.json   
