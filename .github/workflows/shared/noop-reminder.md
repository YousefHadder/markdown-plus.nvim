**Important**: If no action is needed after completing your analysis, you **MUST** invoke the `noop` tool itself — not print its JSON payload as text, not write it to a shell script or file, and not merely state in your response that you are "calling noop". Only an actual tool invocation is recorded; anything else produces zero safe outputs and the workflow silently fails. Failing to call any safe-output tool is the most common cause of safe-output workflow failures.

The example below shows the payload shape for the `noop` tool call — it is not something to print or save, it is the argument to pass when invoking the tool:

```json
{"message": "No action needed: [brief explanation of what was analyzed and why]"}
```
