# model-to-data-challenge-workflow
This repository will serve as a template for the `CWL` workflow and tools required to set up a `model-to-data` challenge infrastructure.

For more information about the tools, please head to [ChallengeWorkflowTemplates](https://github.com/Sage-Bionetworks/ChallengeWorkflowTemplates)


## Requirements
* `pip3 install cwltool`
* A synapse account / configuration file.  Learn more [here](https://docs.synapse.org/articles/client_configuration.html#for-developers)
* A Synapse submission to a queue.  Learn more [here](https://docs.synapse.org/articles/evaluation_queues.html#submissions)

## What to edit

* **workflow.cwl**
  - update L53 (`valueFrom: "syn18081597"`) to the Synapse ID where your workflow is located - **required**
  - remove L82-83 (`id: errors_only...`) if sending a "Submission valid!" email is also wanted (default action is to only send an email if invalid reasons are found) - optional
  - update L135 (`default: []`) with score annotations that are meant to remain prviate from the participant - optional

*  **validate.cwl**
   - update L11 (`dockerPull: python:3.7`) if you are not using a Python script to validate
   - update the lines of code after `entry: |` with your own validation code
      - NOTE: expected annotations to write out are `prediction_file_status` and `prediction_file_errors` (see [ChallengeWorkflowTemplates](https://github.com/Sage-Bionetworks/ChallengeWorkflowTemplates#validation-validatecwl) for more information.)

* **score.cwl**
  - update L11 (`dockerPull: python:3.7`) if you are not using a Python script to score
  - update the lines of code after `entry: |` with your own scoring code


## Testing the workflow locally

```bash
cwltool workflow.cwl --submissionId 12345 \
                      --adminUploadSynId syn12345 \
                      --submitterUploadSynId syn12345 \
                      --workflowSynapseId syn12345 \
                      --synaspeConfig ~/.synapseConfig
```
where:
* `submissionId` - ID of the Synapse submission to process
* `adminUploadSynId` - ID of a Synapse folder accessible only to the submission queue administrator
* `submitterUploadSynId` - ID of a Synapse folder accessible to the submitter
* `workflowSynapseId` - ID of the Synapse entity containing a reference to the workflow file(s)
* `synapseConfig` - filepath to your Synapse credentials
