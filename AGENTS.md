# Instructions

## workflow

for every new task I provide, go into plan mode, start a new branch based on main, checkout that branch, prepare a plan without executing, commit the plan into an .md file in the `plans` folder, named with the date in ISO 8601 format and an abbreviated description of the feature, wait for me to confirm or refine the plan before executing it
if the plan is refined based on my fedback make sure to patch the .md file for the plan as well
when executing the plan, only stage changes, so I can test and refine plan and implementatioon before commit and push - only do commit and push when I ask ask for it

## skills

use the skills found in the `.skills` directory

use the `lotro-plugins-development-skill` only for main plugin implementation work
(Lua source, XML UI/layout, plugin runtime behavior)

for repository infrastructure tasks (for example GitHub Actions, CI/CD, docs, release automation, tooling), do not use that skill unless explicitly requested

default rule: if a task does not modify plugin Lua/XML behavior, do not apply `lotro-plugins-development-skill`

use markdown-documentation skill for writing .md files

## code style

when writing code, do not use ; to end lines as a convention

## changelog data style

when adding lines to changelog and changelogdata, the strings should have a prefix of either major: for major features, feat: for enhancements and minor features, fix: for changes which address behavior that was not as intended

## LOTRO Lua limits

utility classes found in turbine folder can be used but should be considered libraries we cannot change