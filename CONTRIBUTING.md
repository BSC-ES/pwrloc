# How can I contribute?

Thank you for wanting to contribute! :raised_hands: :sparkles:  
There are multiple ways to contribute to the project, ranging from coding tasks to maintaining and organizing the repository.

## Workflow for code and documentation changes

First, create an issue and describe the goal of your code or documentation changes.
Take some time to look through the available tags and select the ones applicable for your change.
Afterwards, create a branch for your changes in which you mention the issue id and shortly describe what you work on.
The format of the branch must be `<type>/#<issue_id>-<description>`, in which you have 3 variables.
The `type` must be one of the following:

- For features: `feature`
- For bug fixes: `bugfix`
- For hotfixes: `hotfix`
- For documentation: `docs`

The `issue_id` is the ID of the issue you created earlier.
Lastly, `description` should be a very short description of what you're changing.

For example, if you found a bug in parsing the user input and your issue has id `#1`, you should create a branch called ```bugfix/#1-parsing-user-input```.
After you have fixed the bug, it's time to create a merge request and open it up for review.
Make sure to merge into the `develop` branch and link the issue for closing upon merging the request.
Someone will review your code changes, and after any potential changes, the branch can be merged into the develop branch.

### Tests for code changes

Whether you're fixing a bug or creating a new feature, we want that functionality to persist over time.
Code bases keep evolving and sometimes some existing functionality might be broken by accident.
The best way to prevent this, is by having a set of tests that check the functionality that you just added.
Please make sure to write tests for anything that you change!

### Pre-commit

The CI/CD system checks for many things that can also be checked locally before pushing your code.
To facilitate this, we use [pre-commit](https://pre-commit.com/) to keep all our coding styles the same.
To get started, create a virtual environment called `venv` and install pre-commit through pip.
Then initialize the pre-commit environment with `pre-commit install` and you're good to go!

Here is a summary of the steps:

```bash
python -m venv venv
source ./venv/bin/activate
pip install pre-commit
pre-commit install
```

Afterwards, pre-commit will be triggered every time you make a commit.
It is also possible to run pre-commit manually through `pre-commit run --all-files`.
This is recommended when using pre-commit for the first time as it'll install all the checks upon the first execution.

## Workflow for releases

Creating a release is quite easy.
First you create a new branch with the name in the format `release/v<version>`.
Here, `version` must follow the [Semantic Versioning](https://semver.org/) specification.
Then you can create a new release by going into the Releases page on GitHub and click "Draft a new release".
Here you can select what branch and/or tag to use for creating the release, and afterwards submit it with the right version corresponding to the one chosen previously.

## Reporting new issues

It is also possible to create new issues without actually making any code or documentation changes.
Simply create a new issue and carefully describe what you would like to see changed.
In the case of bugs, please add instructions for reproducing the bug, including the platform you're running on.
Afterwards, select tags according to the change you'd like to see and create the issue.
