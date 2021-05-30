"""
Reject submissions that are invalid in internal queues
"""
import argparse
import time

import challengeutils
from challengeutils.submission import (
    WORKFLOW_LAST_UPDATED_KEY,
    WORKFLOW_START_KEY,
    TIME_REMAINING_KEY,
)
from challengeutils.annotations import update_submission_status
from challengeutils.utils import (evaluation_queue_query,
                                  update_single_submission_status)
import pandas as pd
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


def update_status(syn: Synapse, queue_info: pd.Series):
    """If internal submission is invalid, then make update main leaderboard
    with site_submission_status to INVALID

    Args:
        syn: Synapse connection
        queue_info: One row of queue mapping information
                    {"main": main queue
                     "internal": internal queue
                     "site": site}
    """
    # Get submissions that are processing in internal queues
    processing_subs = (
        f"select objectId from evaluation_{queue_info['main']} where "
        f"{queue_info['site']}_submission_status == 'EVALUATION_IN_PROGRESS'"
    )
    processing_submissions = list(
        evaluation_queue_query(syn, processing_subs)
    )
    # For all the submisisons that are processing, obtain the status in
    # the internal queues.  Make main submission invalid.
    for sub in processing_submissions:
        internal_query_str = (
            f"select name from evaluation_{queue_info['internal']} where "
            f"status == 'INVALID' and name == '{sub['objectId']}'"
        )
        internal_subs = list(evaluation_queue_query(syn, internal_query_str))
        if internal_subs:
            internal_status = {
                f"{queue_info['site']}_submission_status": "INVALID"
            }
            annotate_with_retry(syn=syn, submissionid=internal_subs[0]['name'],
                                annotation_dict=internal_status,
                                is_private=False)
            # TODO: email participant here


def convert_overall_status(syn: Synapse, main_queueid: str, sites: list,
                           submission_viewid: str):
    """If all internal sites have INVALID status, make main status REJECTED
    """
    # Format site query str
    site_status_keys = [f"{site}_submission_status == 'INVALID'"
                        for site in sites]
    site_strs = " and ".join(site_status_keys)
    # Get submissions that have all sites that are invalid
    query_str = (
        f"select id from {submission_viewid} where "
        f"{site_strs} and status != 'REJECTED' "
        f"and evaluationId = '{main_queueid}'"
    )
    print(query_str)
    invalid_subs = syn.tableQuery(query_str)
    invalid_subsdf = invalid_subs.asDataFrame()
    for _, row in invalid_subsdf.iterrows():
        print(row['id'])
        annotate_with_retry(syn=syn, submissionid=row['id'],
                            status="REJECTED")


def stop_submission_over_quota(syn, submission_id, quota):
    """Stop submission over quota.  This is implemented as a safeguard
    in case the tracking of the time quota in the workflow is stuck
    within the for loop
    """
    status = syn.getSubmissionStatus(submission_id)
    last_updated = status.submissionAnnotations[WORKFLOW_LAST_UPDATED_KEY]
    workflow_start = status.submissionAnnotations[WORKFLOW_START_KEY]
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
    parser.add_argument('--username', type=str,
                        help='Synapse Username')
    parser.add_argument('--password', type=str,
                        help="Synapse Password")
    parser.add_argument('--config', type=str,
                        help="yaml configuration")
    parser.add_argument('--quota', type=int, default=7200,
                        help="Runtime quota in seconds")
    args = parser.parse_args()
    syn = synapseclient.Synapse()
    syn.login(email=args.username, password=args.password)
    with open(args.config, "r") as config_f:
        configuration = yaml.safe_load(config_f)

    for main_queueid, queue_info in configuration.items():
        evaluation = syn.getEvaluation(main_queueid)
        print(f"Checking '{evaluation.name}'")
        running_submissions = syn.getSubmissions(
            main_queueid, status="EVALUATION_IN_PROGRESS"
        )
        for running_submission in running_submissions:
            print(running_submission)
            stop_submission_over_quota(syn, submission_id=running_submission['id'],
                                       quota=queue_info['runtime'])

        if queue_info['submit_to'] is not None:
            time.sleep(5)
            internal_sites = [configuration[internal]['center']
                              for internal in queue_info['submit_to']]
            convert_overall_status(syn, main_queueid, internal_sites,
                                   queue_info['submission_viewid'])


if __name__ == "__main__":
    main()
