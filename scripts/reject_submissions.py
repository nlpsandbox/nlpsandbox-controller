"""
Reject submissions that are invalid in internal queues
"""
import argparse
import time

from challengeutils.submission import (
    WORKFLOW_LAST_UPDATED_KEY,
    WORKFLOW_START_KEY,
    TIME_REMAINING_KEY,
)
from challengeutils.annotations import update_submission_status
from challengeutils.utils import update_single_submission_status
import synapseclient
from synapseclient.core.retry import with_retry
from synapseclient import Synapse
import yaml


class MockResponse:
    """Mocked status code to return"""
    status_code = 200


def annotate_submission(syn: Synapse, submissionid: str,
                        annotation_dict: dict = None, status: str = None,
                        is_private: bool = True,
                        force: bool = False) -> MockResponse:
    """Annotate submission with annotation values from a dict

    Args:
        syn: Synapse object
        submissionid: Submission id
        annotation_dict: Annotation dict
        status: Submission Status
        is_private: Set annotations acl to private (default is True)
        force: Force change the annotation from
               private to public and vice versa.

    Returns:
        MockResponse

    """
    sub_status = syn.getSubmissionStatus(submissionid)
    # Update the status as well
    if status is not None:
        sub_status.status = status
    if annotation_dict is None:
        annotation_dict = {}
    # Don't add any annotations that are None
    annotation_dict = {key: annotation_dict[key] for key in annotation_dict
                       if annotation_dict[key] is not None}
    sub_status = update_single_submission_status(sub_status, annotation_dict,
                                                 is_private=is_private,
                                                 force=force)
    sub_status = update_submission_status(sub_status, annotation_dict)
    syn.store(sub_status)
    return MockResponse


def annotate_with_retry(**kwargs):
    """Annotates submission status with retry to account for
    conflicting submission updates

    Args:
        **kwargs: Takes same parameters as annotate_submission
    """
    with_retry(annotate_submission(**kwargs),
               wait=3,
               retries=10,
               retry_status_codes=[412, 429, 500, 502, 503, 504],
               verbose=True)


def update_status(syn: Synapse, main_queue: str, internal_queue: str,
                  config: dict):
    """If internal submission is invalid, then make update main leaderboard
    with site_submission_status to INVALID

    Args:
        syn: Synapse connection
    """
    main_sub_viewid = config[int(main_queue)]['submission_viewid']
    internal_sub_viewid = config[int(internal_queue)]['submission_viewid']
    site = config[int(internal_queue)]['center']
    # Get submissions that are annotated as processing in internal queues
    # Processing submissions will be annotated with EVALUATION_IN_PROGRESS
    # in the main queue
    processing_subs_query_str = (
        f"select id from {main_sub_viewid} where "
        f"{site}_submission_status = 'EVALUATION_IN_PROGRESS'"
    )
    processing_submissions = syn.tableQuery(processing_subs_query_str)
    processing_submissionsdf = processing_submissions.asDataFrame()
    # For all the submissions that are processing, obtain the status in
    # the internal queues.  Make main submission invalid.
    for subid in processing_submissionsdf['id']:
        internal_query_str = (
            f"select name from {internal_sub_viewid} where "
            f"status = 'INVALID' and name = '{subid}'"
        )
        internal_subs = syn.tableQuery(internal_query_str)
        internal_subsdf = internal_subs.asDataFrame()
        if not internal_subsdf.empty:
            internal_status = {
                f"{site}_submission_status": "INVALID"
            }
            annotate_with_retry(syn=syn, submissionid=internal_subsdf['name'][0],
                                annotation_dict=internal_status,
                                is_private=False)
            # TODO: email participant here


def convert_overall_status(syn: Synapse, main_queueid: str, sites: list,
                           submission_viewid: str):
    """If all internal sites have INVALID status, make main status REJECTED
    """
    # Format site query str
    site_status_keys = [f"{site}_submission_status = 'INVALID'"
                        for site in sites]
    site_strs = " or ".join(site_status_keys)
    # Get submissions that have all sites that are invalid
    query_str = (
        f"select id from {submission_viewid} where "
        f"({site_strs}) and status <> 'REJECTED' "
        f"and evaluationid = '{main_queueid}'"
    )
    print(query_str)
    invalid_subs = syn.tableQuery(query_str)
    invalid_subsdf = invalid_subs.asDataFrame()
    for _, row in invalid_subsdf.iterrows():
        annotate_with_retry(syn=syn, submissionid=row['id'],
                            status="REJECTED")


def stop_submission_over_quota(syn, submission_id, quota):
    """Stop submission over quota.  This is implemented as a safeguard
    in case the tracking of the time quota in the workflow is stuck
    within the for loop
    """
    status = syn.getSubmissionStatus(submission_id)
    last_updated = status.submissionAnnotations.get(
        WORKFLOW_LAST_UPDATED_KEY, 0
    )
    workflow_start = status.submissionAnnotations.get(
        WORKFLOW_START_KEY, 0
    )
    # in case annotations are lists, make sure to return the element
    if isinstance(last_updated, list):
        last_updated = last_updated[0]
    if isinstance(workflow_start, list):
        workflow_start = workflow_start[0]

    runtime = last_updated - workflow_start
    # Add 10 minutes to quota for all the initialization and storing
    # prediction steps
    if runtime > quota + 600:
        add_annotations = {TIME_REMAINING_KEY: 0}
        annotate_with_retry(syn=syn, submissionid=submission_id,
                            annotation_dict=add_annotations,
                            is_private=False)


def main():
    """Invoke REJECTION"""
    parser = argparse.ArgumentParser(description='Reject Submissions')
    # parser.add_argument('config', type=str, help="yaml configuration")
    parser.add_argument(
        '--username', type=str,
        help='Synapse Username. Do not specify this when using PAT'
    )
    parser.add_argument('--credential', type=str,
                        help="Synapse api key or personal access token")
    parser.add_argument('--quota', type=int, default=7200,
                        help="Runtime quota in seconds")
    args = parser.parse_args()
    syn = synapseclient.Synapse()
    if args.username is None and args.credential is None:
        syn.login()
    elif args.username is not None:
        syn.login(email=args.username, apiKey=args.credential)
    else:
        syn.login(authToken=args.credential)
    # get configuration
    queue_mapping_table = syn.tableQuery("select * from syn25952454")
    queue_mappingdf = queue_mapping_table.asDataFrame()
    queue_mappingdf.index = queue_mappingdf['queue_id']
    queue_mappingdf['dataset_version'] = queue_mappingdf['dataset_version'].astype(str)
    configuration = queue_mappingdf.to_dict("index")
    # with open(args.config, "r") as config_f:
    #     configuration = yaml.safe_load(config_f)

    for main_queueid, queue_info in configuration.items():
        evaluation = syn.getEvaluation(main_queueid)
        print(f"Checking '{evaluation.name} ({main_queueid})'")
        running_submissions = syn.getSubmissions(
            main_queueid, status="EVALUATION_IN_PROGRESS"
        )
        for running_submission in running_submissions:
            print(running_submission)
            stop_submission_over_quota(
                syn, submission_id=running_submission['id'],
                quota=queue_info['runtime']
            )
        time.sleep(5)
        if queue_info['submit_to'] is not None:
            internal_sites = [configuration[int(internal)]['center']
                              for internal in queue_info['submit_to']]
            for internal_queue in queue_info['submit_to']:
                update_status(syn=syn, main_queue=main_queueid,
                              internal_queue=internal_queue,
                              config=configuration)
            convert_overall_status(
                syn=syn, main_queueid=main_queueid,
                sites=internal_sites,
                submission_viewid=queue_info['submission_viewid']
            )


if __name__ == "__main__":
    main()
