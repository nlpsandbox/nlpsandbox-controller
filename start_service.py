"""Run training synthetic docker models"""
import argparse
import getpass
import time

import docker


def main(args):
    """Run docker model"""
    client = docker.from_env()

    print(getpass.getuser())

    docker_image = args.docker_repository + "@" + args.docker_digest

    # Look for if the container exists already, if so, reconnect
    print("checking for containers")
    container = None
    for cont in client.containers.list(all=True):
        if args.submissionid in cont.name:
            # Must remove container if the container wasn't killed properly
            if cont.status == "exited":
                cont.remove()
            else:
                container = cont
    # If the container doesn't exist, make sure to run the docker image
    if container is None:
        # Run as detached, logs will stream below
        print("starting service")
        # Created bridge docker network that is only accessible to other
        # containers on the same network
        # docker network create --internal submission
        # docker run --network submission \
        #            -d nlpsandbox/date-annotator-example:latest
        # Limit to 4 CPU usage (cpu_period=100000, cpu_quota=400000)
        # TODO: need to parametrize the amount of memory and cpu shares
        container = client.containers.run(docker_image,
                                          detach=True, name=args.submissionid,
                                          # network_disabled=True,
                                          network="submission",
                                          cpu_period=100000,
                                          cpu_quota=400000,
                                          mem_limit='4g', stderr=True)
                                          #ports={'8080': '8081'})
        # sleep for 60 seconds just in case it takes time to start the service
        time.sleep(60)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--submissionid", required=True,
                        help="Submission Id")
    parser.add_argument("-p", "--docker_repository", required=True,
                        help="Docker Repository")
    parser.add_argument("-d", "--docker_digest", required=True,
                        help="Docker Digest")
    args = parser.parse_args()

    main(args)
