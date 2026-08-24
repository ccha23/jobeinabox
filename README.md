# JobeInABox

![Docker Stars](https://img.shields.io/docker/stars/trampgeek/jobeinabox.svg)
![Docker Pulls](https://img.shields.io/docker/pulls/trampgeek/jobeinabox.svg)
![Docker Automated](https://img.shields.io/docker/cloud/automated/trampgeek/jobeinabox.svg)
![Docker Build](https://img.shields.io/docker/cloud/build/trampgeek/jobeinabox.svg)

The [Moodle CodeRunner question type plugin](https://moodle.org/plugins/qtype_coderunner) requires a [Jobe server](https://github.com/trampgeek) on which to run student-submitted jobs. [JobeInABox](https://hub.docker.com/r/trampgeek/jobeinabox/) is a Docker image that provides a basic Jobe server that runs all the standard languages. For full information on Jobe servers, see the 
[full Jobe documentation](https://github.com/trampgeek/jobe)

*NOTE: for security and performance reasons it is strongly recommended to run Jobe on a 
dedicated standalone server, even when running it in a container.*

## Building and running your own image locally (strongly recommended)

There are several ways to build and run a JobeInABox container, for example:

* [Podman](https://developers.redhat.com/blog/2019/02/21/podman-and-buildah-for-docker-users/)
* [Docker](https://docs.docker.com/)

For production use you should build your own image using the local timezone. In this example we use Docker as follows:

Pull [this repo from Github](https://github.com/trampgeek/jobeinabox), cd into the jobeinabox directory and type a command
of the form

    sudo docker build . -t my/jobeinabox --build-arg TZ="Europe/Amsterdam"

You can then run your newly-built image with the command

    sudo docker run -d -p 4000:80 --name jobe my/jobeinabox

This will give you a jobe server running on port 4000, which can then be
tested locally and used by Moodle as explained in the section "Using jobeinabox" below.

### Building and releasing with `make`

This repo ships a `Makefile` (in the same style as the DIVE jupyter notebooks
repo) so the image can be built and versioned reproducibly. The image version
lives in this public repo (`jobeinabox := jobeinabox^<version>`), so bump it to
release a new tag:

    make image-info.jobeinabox           # show the parsed image name/tag
    make docker-build.jobeinabox^1.0.0   # build locally as jobeinabox:1.0.0
    make docker-push.jobeinabox^1.0.0 registry=localhost:32000   # push to a registry
    make image.jobeinabox^1.0.0 registry=localhost:32000         # build + push

The registry is *not* hardcoded to any deployment-specific host: by default the
build is local only, and `docker-push`/`image` use whatever `registry=` you pass
(defaulting to the generic `localhost:32000`). Deployment tooling may override
the registry (e.g. to a cluster-internal one) so that nodes can pull the image.

## Using the pre-built jobeinabox image on docker hub

To run the pre-built Docker Hub image, just enter the command:

    sudo docker run -d -p 4000:80 --name jobe trampgeek/jobeinabox:latest

This will give you a jobe server running on port 4000, which can then be
tested locally and used by Moodle as explained in the section "Using jobeinabox" below.

## Setting the number of jobe users

By default, Jobe will run up to 8 jobs simultaneously. This is usually a suitable
value for 8-core systems but if you have more cores available you will probably
want to raise this number. To do so, exec a shell in the container with a command of the form

    docker exec -it jobe bash

 and then:

    nano  /var/www/html/jobe/app/Config/Jobe.php

Find the line

    public int $jobe_max_users = 8;

and change the value from 8 to the number of cores on your machine, or to a higher
value if you expect to run mainly I/O-bound jobs.

Then re-install Jobe (within the container) with the commands:

    cd /var/www/html/jobe
    ./install --purge

## Checking performance

You can check the performance of the container with the command

    docker exec -it jobe /var/www/html/jobe/testsubmit.py --perf

## Using API Keys

You can provide API keys during the image build via the `--secret` option.

The keys can be stored in a separate file, following the format:

```
'c1425880-2289-4b76-ae29-bcea34997256' => 0,
'de7970e6-0466-4ce2-a6a4-c1a51363bd03' => 90
```

You can find more information on API keys in the Jobe documentation.

With the following command the keys stored in a file called `api_keys` in the
jobeinabox directory are automatically added to `/var/www/html/jobe/app/Config/Jobe.php`
and the option `$require_api_keys` is set to true.

```
podman build . -t my/jobeinabox --secret id=api_keys,src=api_keys
```

If no API keys are provided the configuration remains untouched.

### Warnings:

1.  The image is over 1 GB, so may take a long time to start the first
    time, depending on your download bandwidth.

## Using jobeinabox

### Initial sanity check
Having started a jobeinabox container by either of the above methods, you
can check it's running OK by browsing to

     http://[host_running_docker]:4000/jobe/index.php/restapi/languages

and you should get a JSON-encoded list of the supported languages, something like
(depending on OS version):

    [["c","7.3.0"],["cpp","7.3.0"],["java","10.0.2"],["nodejs","8.10.0"],["octave","4.2.2"],["pascal","3.0.4"],["php","7.2.7"],["python3","3.6.5"]]
    
### Running the test suite

If you wish to run the test suite within the container, use the command

    sudo docker exec -t jobe /usr/bin/python3 /var/www/html/jobe/testsubmit.py
    
### Configuring Moodle to use JobeInABox

To set your Moodle/CodeRunner plugin to use this dockerised Jobe server,
set the Jobe server field in the CodeRunner admin settings (Site Administration > Plugins > Question types > CodeRunner) to

    [host_running_docker]:4000

Do not put http:// at the start.

In addition you will need to:

1.  Add the port number 4000 to the cURL allowed ports list in the HTTP security
    settings for the Moodle server (in Site administration > Security)
    
1.  If you're running JobeInABox on the same host as your Moodle server
    (not recommended) you will have to additionally remove *localhost*
    and *127.0.0.0/8* from the cURL blocked hosts list.
    
### Stopping JobeInABox

To stop the running server, enter the command:

    sudo docker stop jobe

To remove the running server, enter the command:

    sudo docker rm jobe

To check if there is anything left, enter the command

    sudo docker ps -a

## Notes on security:

1.  Note that while the container in which this Jobe runs should be secure, the
    container's network is currently just bridged across to the host's network.
    This means that Jobe can be accessed from anywhere that can access the host
    and can access any URI that the host can access. Firewalling of the host is
    essential for production use.

1.  Rebuild the container regularly to ensures that it is running
    with the latest jobe version and security updates.

## Change history (recent changes only)

24/8/26:
 * Upgrade base image from Ubuntu 24.04 to 26.04 (Python 3.14, GCC/G++ 15 with
   C++23, PHP 8.5, Node 22, JDK 25, Octave 11).
 * Fix the apache2 locale patch: the previous unanchored `sed` produced the
   invalid locale `C.UTF-8.UTF-8` on 26.04, which made the JVM emit `?` instead
   of UTF-8 accents. Now anchored + idempotent (`s/^export LANG=.*/.../`).
 * Add a `Makefile` (jupyter-style) so the image can be built, tagged, and
   pushed with `make`; the image version is tracked in this repo.
 * Note: Octave 11's new `--version` string is not matched by Jobe's regex, so
   the languages endpoint reports octave as "Unknown" (cosmetic; octave still
   runs). See Jobe upstream `app/Libraries/OctaveTask.php`.

8/6/26:
 * Update README.md to include required Moodle security settings (allowed ports,
   disallowed URLs).
   
18/10/24:
 * API key configuration can now be specified during build using Docker's "--secret" functionality (thanks @theLogicJB).

 * Fix broken documentation on changing the number of Jobe servers.



