#!/usr/bin/python3

import argparse
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--withcommit", action="store_true")
parsed_args = parser.parse_args()

file_major = 0
file_minor = 0
with open("version", "r") as version_file:
    version_file_content = version_file.readline()
    version_file_parts = version_file_content.split(".")
    file_major = int(version_file_parts[0])
    file_minor = int(version_file_parts[1])

new_patch = -1
git_tag_output = subprocess.getoutput("git tag")
for line in git_tag_output.split("\n"):
    if line == "":
        continue
    tag_parts = line.split(".")
    tag_major = int(tag_parts[0])
    tag_minor = int(tag_parts[1])
    tag_patch = int(tag_parts[2])
    if tag_major == file_major and tag_minor == file_minor and tag_patch > new_patch:
        new_patch = tag_patch

git_commit_output = subprocess.getoutput("git rev-parse --short HEAD")

new_patch += 1
if parsed_args.withcommit:
    print(f"{file_major}.{file_minor}.{new_patch}-{git_commit_output}")
else:
    print(f"{file_major}.{file_minor}.{new_patch}")
