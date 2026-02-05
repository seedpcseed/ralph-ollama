## prd.json prompt

>  In projects/editio, I ran 
> aider --no-git --yes --no-auto-commits --model ollama/glm-4.7-flash:latest --timeout 1200   --no-stream --no-show-model-warnings --no-auto-lint  prd.md

You are an expert in project architecture planning and converting prd to a json file that breaks down the overall project into smaller stories that can be iterated over to create high quality functional code. When the stories are combined the end product will be a complete product that is true to the intent of the prd.md. The number of stories should be between 10 and 25 and each should have a major action associated with them. Edit projects/editio/prd.json: replace its entire contents with a JSON object that has "version": "2.0", "branchName": "ralph/editio", "createdAt", "updatedAt", and "userStories": [ ... ] — an array of story objects in v2.0 format. Create stories in dependency order (infrastructure → core → features → polish). Include verification commands in acceptance criteria or verify field. Each story needs this: id, category, story, steps, acceptance, priority, status "pending", progress 0, lastAttempt null, attemptCount 0, dependsOn, blocks, verify{command, lastRun, lastResult "not_run", expectedResult "pass"}, files, tests, errors, notes "", createdAt, updatedAt. 

## refine prd.json stories prompt

> In projects/editio, I ran 
> aider --no-git --yes --no-auto-commits --model ollama/glm-4.7-flash:latest --timeout 1200   --no-stream --no-show-model-warnings --no-auto-lint  prd.md prd.json requirements.md 

You are an expert in project architecture planning and converting prd to a json file that breaks down the overall project into smaller stories that can be iterated over to create high quality functional code. You already created prd.json. You need to review prd.json and determine if each story can be completed in a maximum of 10 min or if the complexity of the story is too high for completion in that time. If the story cannot be completed, you need to break down the story into additional stories that can be completed in that time. You need to directly edit the prd.json. Do not ask the user to do the editing for you. You must strictly abide by the structure of the prd.json. Do not change the JSON object components as you make modifications including breaking apart stories into smaller stories. 

## requirements.md prompt

You are an expert in project architecture planning and converting prd to a requirements.md file that breaks down the overall project into smaller stories that can be iterated over to create high quality functional code. When the stories are combined the end product will be a complete product that is true to the intent of the prd.md. The number of stories should be between 10 and 25 and each should have a major action associated with them. Edit projects/editio/requirements.md: replace its entire contents with a requirements.md file that has all the necessary technical specs from prd.md

## run prompt
you are an autonomous agent working to create a complete product that is true to the intent of the prd.md. you will read prd.md, prd.json, and requirements.md. you will pick the highest priority story where status is not "complete". you will implement that ONE story completely under the project path projects/editio/. you will run verification (e.g. cargo check, pytest) when the task specifies it. you will at end of response include status block.

```
---RALPH_STATUS---
STATUS: IN_PROGRESS | COMPLETE | BLOCKED
TASKS_COMPLETED_THIS_LOOP: <n>
FILES_MODIFIED: <n>
TESTS_STATUS: PASSING | FAILING | NOT_RUN
WORK_TYPE: IMPLEMENTATION | TESTING | DOCUMENTATION
EXIT_SIGNAL: false | true
RECOMMENDATION: <one line>
---END_RALPH_STATUS---
```

You will set the EXIT_SIGNAL: true only when all the stories are done and the verifications have passed. Use BLOCKED when stuck on same error; RECOMMENDATION should say what's needed next.

Work on only one story at a time where the lower number is the highest priority. You must create and edit files. Do not ask the user to add or edit the files for you. this is your job. Do not put information into logs or alternative files. Put them into the files instructed. Implementation is greater than tests for new code. No placeholder implementations.