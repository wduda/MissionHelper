# Instructions

## workflow

every plan you prepare needs to have the following first steps: save the plan into an .md file in the `plans` folder, named with the date in ISO 8601 format and an abbreviated description of the feature, wait for the user to confirm said plan
if you user asks to update or refine the plan then the first step of the updated plan is to update said .md file with the plan as first step and wait for confirmation

## skills

use the skills found in the `.skills` directory

use the lotro-plugins-development-skill skill for work on the main project
use the git-commit skill for preparing git commit
use markdown-documentation skill for writing .md files

## code style

when writing code, do not use ; to end lines as a convention
when writing .md files, never use emphasis instead of headings
when writing .md files, headings should be surrounded by blank lines
when writing .md files, leave out your questions that usually come at the end

## changelog data style

when adding lines to changelog and changelogdata, the strings should have a prefix of either major: for major features, feat: for enhancements and minor features, fix: for changes which address behavior that was not as intended

## LOTRO Lua limits

utility classes found in turbine folder can be used but should be considered libraries we cannot change
