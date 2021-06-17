"""Script to revoke submit access to the participant queues
in the case of scheduled and unscheduled maintenance"""
import argparse
import os

import challengeutils
import synapseclient
import yaml


def toggle(syn: synapseclient.Synapse, config: dict, mode: str):
    """Switch queue permissions for NLP users from view to submit or vice versa
    
    Args:
        syn: Synapse connection
        config: controller queue configuration
        mode: open or close queues
    """

    if mode == "open":
        permission = "submit"
    elif mode == "close":
        permission = "view"
    else:
        raise ValueError("Mode can only be open or close")

    user_team_id = 3413388
    for queue in config:
        queue_obj = syn.getEvaluation(queue)
        # Get main submission queues
        if (queue_obj.name.startswith("NLP sandbox") and
            "- Test" not in queue_obj.name):
            print(queue_obj.name)
            challengeutils.permissions.set_evaluation_permissions(
                syn=syn,
                evaluation=queue,
                principalid=user_team_id,
                permission_level=permission
            )


def main():
    """Toggle queues"""
    parser = argparse.ArgumentParser(description='Toggle queue permissions')
    parser.add_argument('mode', type=str, choices=['open', 'close'],
                        help="Open or close the queue")
    args = parser.parse_args()
    # Log into synapse
    syn = synapseclient.login()
    # Read in configuration yml at root github dir
    script_dir = os.path.dirname(os.path.realpath(__file__))
    with open(os.path.join(script_dir, "../config.yml"), "r") as config_o:
        config = yaml.safe_load(config_o)
    
    toggle(syn, config, args.mode)


if __name__ == "__main__":
    main()
