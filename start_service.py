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
    for cont in client.containers.list(all=True, ignore_removed=True):
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
                                          mem_limit='7g', stderr=True)
                                          #ports={'8080': '8081'})
        # Make sure the service has started
        container_started = False
        time_now = time.time()
        while not container_started:
            if time.time() - time_now > 600:
                raise ValueError(
                    "Getting docker image shouldn't take longer than 10 min"
                )
            try:
                client.containers.get(args.submissionid)
                container_started = True
            except docker.errors.NotFound:
                time.sleep(60)
        time.sleep(70)


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
