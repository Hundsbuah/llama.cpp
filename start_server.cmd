@echo off
setlocal EnableExtensions DisableDelayedExpansion
title llama-server

rem ============================================================
rem This CMD contains the qwen3.8-safe-v2 Jinja template internally.
rem Put only this CMD in the repository root, e.g.:
rem Expected server:
rem   build\bin\Release\llama-server.exe
rem ============================================================

cd /d "%~dp0"

rem ---------- Paths ----------
set "SERVER=%~dp0build\bin\Release\llama-server.exe"
set "SELF=%~f0"
set "TEMPLATE=%TEMP%\qwen3.8-safe-v2-%RANDOM%-%RANDOM%.jinja"
set "MODEL_ROOT=%USERPROFILE%\.lmstudio\models"
set "MODEL_NAME=Qwen3.8-27B-UD-Q4_K_XL.gguf"
set "MODEL="

rem ---------- Locate model automatically ----------
if exist "%MODEL_ROOT%" (
    for /f "delims=" %%F in ('where /r "%MODEL_ROOT%" "%MODEL_NAME%" 2^>nul') do (
        if not defined MODEL set "MODEL=%%~fF"
    )
)

rem ---------- Validate files ----------
if not exist "%SERVER%" (
    echo ERROR: llama-server.exe not found:
    echo   "%SERVER%"
    echo.
    echo Build the project first, then run this CMD again.
    pause
    exit /b 1
)

rem ---------- Extract embedded Jinja template ----------
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$raw=[IO.File]::ReadAllText($env:SELF);" ^
  "$marker=':__QWEN38_JINJA_PAYLOAD__';" ^
  "$p=$raw.LastIndexOf($marker);" ^
  "if($p -lt 0){exit 1};" ^
  "$tpl=$raw.Substring($p+$marker.Length).TrimStart([char]13,[char]10);" ^
  "[IO.File]::WriteAllText($env:TEMPLATE,$tpl,[Text.UTF8Encoding]::new($false))"
if errorlevel 1 (
    echo ERROR: Embedded Jinja template could not be extracted.
    pause
    exit /b 1
)

if not exist "%TEMPLATE%" (
    echo ERROR: Temporary chat template was not created:
    echo   "%TEMPLATE%"
    pause
    exit /b 1
)

if not defined MODEL (
    echo ERROR: Model not found automatically:
    echo   "%MODEL_ROOT%\...\%MODEL_NAME%"
    echo.
    echo Edit MODEL_ROOT / MODEL_NAME at the top of this CMD if needed.
    pause
    exit /b 1
)

rem ---------- Verify this is the MindControl-capable build ----------
"%SERVER%" --help 2>&1 | findstr /C:"--reasoning-budget-enable" >nul
if errorlevel 1 (
    echo ERROR: This llama-server build does not expose --reasoning-budget-enable.
    echo Build the merged llama-mindcontrol / PR #25961 source first.
    pause
    exit /b 1
)

rem ---------- Free VRAM used by LM Studio, if LMS CLI is available ----------
where lms >nul 2>&1
if not errorlevel 1 (
    echo Unloading LM Studio models...
    lms unload --all >nul 2>&1
)

rem ============================================================
rem MindControl
rem ============================================================
set "LLAMA_ARG_THINK_BUDGET_ENABLE=1"
set "LLAMA_ARG_THINK_BUDGET=16384"
set "LLAMA_ARG_THINK_BUDGET_SOFT_RATIO=0.85"
set "LLAMA_ARG_THINK_BUDGET_SOFT_MESSAGE=I am approaching my reasoning limit. I should consolidate the key points, resolve any remaining uncertainty, and work toward a final answer while I still have room."
set "LLAMA_ARG_THINK_BUDGET_GRACE_TOKENS=256"
set "LLAMA_ARG_THINK_BUDGET_MESSAGE=I have enough information to answer now.\n</think>"

rem Explicitly disable the optional intro injection in the command below.

rem ============================================================
rem Qwen3.8 chat-template settings
rem ============================================================
set "LLAMA_ARG_CHAT_TEMPLATE_KWARGS={"enable_thinking":true,"preserve_thinking":true,"reasoning_effort":"medium"}"

rem ============================================================
rem Display effective launcher config
rem ============================================================
echo.
echo ============================================================
echo Qwen3.8-27B MindControl
echo ============================================================
echo Server:        "%SERVER%"
echo Model:         "%MODEL%"
echo Template:      embedded qwen3.8-safe-v2
echo API:           http://127.0.0.1:8080/v1
echo Context:       120064
echo GPU layers:    66
echo KV cache:      Q8_0 / Q8_0
echo Temperature:   1.0
echo Top-K:         20
echo Top-P:         0.95
echo Reasoning:     medium
echo Budget:        16384
echo Soft warning:  85%%
echo Grace tokens:  256
echo Fit target:     8 MiB
echo Intro message: disabled
echo ============================================================
echo.

rem ============================================================
rem Start llama-server
rem ============================================================
"%SERVER%" ^
  -m "%MODEL%" ^
  --alias "qwen3.8-27b" ^
  --host 127.0.0.1 ^
  --port 8080 ^
  -c 120064 ^
  -ngl 66 ^
  -t 16 ^
  -tb 16 ^
  -b 2048 ^
  -ub 512 ^
  -np 1 ^
  --no-kv-unified ^
  --ctx-checkpoints 32 ^
  --checkpoint-min-step 256 ^
  --kv-offload ^
  --load-mode mmap ^
  -fa on ^
  -ctk q8_0 ^
  -ctv q8_0 ^
  --seed -1 ^
  --temp 1.0 ^
  --top-k 20 ^
  --top-p 0.95 ^
  --min-p 0.0 ^
  --repeat-penalty 1.0 ^
  --presence-penalty 0.0 ^
  --frequency-penalty 0.0 ^
  --spec-type draft-mtp ^
  --spec-draft-n-max 3 ^
  --spec-draft-n-min 0 ^
  --spec-draft-p-min 0.75 ^
  --spec-draft-type-k q8_0 ^
  --spec-draft-type-v q8_0 ^
  --fit-target 8 ^
  --jinja ^
  --chat-template-file "%TEMPLATE%" ^
  --reasoning on ^
  --reasoning-preserve ^
  --reasoning-format deepseek ^
  --reasoning-budget-intro-message ""
rem  --log-verbose ^
rem  --log-timestamps ^
rem  --log-prefix ^
rem  --log-colors off ^
rem  --log-file "C:\GIT\llama.cpp\llama-server.log" ^
rem  --log-prompts-dir "C:\GIT\llama.cpp\prompt-logs"

set "RC=%ERRORLEVEL%"
del /q "%TEMPLATE%" >nul 2>&1
echo.
echo llama-server exited with code %RC%.
pause
exit /b %RC%

:__QWEN38_JINJA_PAYLOAD__
{%- set template_version = "qwen3.8-safe-v2" %}
{#- -------------------------------------------------------------------------
    Whitespace contract: every tag opener in this file carries a leading minus,
    so it strips the whitespace and newlines that precede it. All emitted text
    comes from string literals, which makes the rendered prompt byte-exact and
    free of incidental newlines. Comment tags need the minus just as much as
    block tags do; a plain comment tag breaks the strip chain and leaks the
    surrounding indentation into the prompt.
    ------------------------------------------------------------------------- -#}
{#- The message list has to exist before anything else can inspect it. -#}
{%- if not messages %}
    {{- raise_exception('No messages provided.') }}
{%- endif %}
{#- -------------------------------------------------------------------------
    Configuration
    ------------------------------------------------------------------------- -#}
{%- set _requested_tool_format =
    tool_call_format if tool_call_format is defined else 'auto'
%}
{%- if _requested_tool_format not in ('auto', 'xml', 'json') %}
    {{- raise_exception(
        'Unexpected tool_call_format ' ~ _requested_tool_format ~
        '. Supported values are auto (default), xml, and json.'
    ) }}
{%- endif %}
{%- set add_vision_id = add_vision_id if add_vision_id is defined else false %}
{%- set enable_thinking = enable_thinking if enable_thinking is defined else true %}
{%- set auto_disable_thinking_with_tools =
    auto_disable_thinking_with_tools
    if auto_disable_thinking_with_tools is defined
    else false
%}
{%- if preserve_reasoning is defined
       and preserve_reasoning is not none
       and preserve_thinking is defined
       and preserve_thinking is not none
       and preserve_reasoning != preserve_thinking %}
    {{- raise_exception(
        'preserve_reasoning and preserve_thinking were both provided with conflicting values.'
    ) }}
{%- endif %}
{%- if preserve_reasoning is defined and preserve_reasoning is not none %}
    {%- set _preserve_thinking = preserve_reasoning %}
{%- elif preserve_thinking is defined and preserve_thinking is not none %}
    {%- set _preserve_thinking = preserve_thinking %}
{%- else %}
    {%- set _preserve_thinking = true %}
{%- endif %}
{%- set max_tool_arg_chars =
    max_tool_arg_chars if max_tool_arg_chars is defined else 0
%}
{%- set max_tool_response_chars =
    max_tool_response_chars if max_tool_response_chars is defined else 0
%}
{%- if max_tool_arg_chars is not number or max_tool_arg_chars < 0 %}
    {{- raise_exception('max_tool_arg_chars must be a non-negative number.') }}
{%- endif %}
{%- if max_tool_response_chars is not number or max_tool_response_chars < 0 %}
    {{- raise_exception('max_tool_response_chars must be a non-negative number.') }}
{%- endif %}
{%- if tools is defined and tools is not none and tools %}
    {%- if tools is string or tools is mapping or tools is not iterable %}
        {{- raise_exception('tools must be an iterable list of tool definitions.') }}
    {%- endif %}
    {%- set _has_tools = true %}
{%- else %}
    {%- set _has_tools = false %}
{%- endif %}
{#- -------------------------------------------------------------------------
    Resolve the tool-call wire format.

    OpenAI-compatible servers hand assistant tool calls back with
    `function.arguments` as a JSON *string*, not a mapping. The XML parameter
    form needs the individual key/value pairs, and a chat template cannot
    decode a JSON string: the standard chat-template environment provides
    `tojson` but no inverse, and no codepoint-to-character primitive, so a
    hand-rolled scanner could not decode \uXXXX escapes correctly. Guessing
    would silently corrupt tool arguments, which is worse than any error.

    So when the caller does not pin a format, render the whole prompt in the
    JSON tool-call form if any tool call in the history carries string
    arguments. That is lossless, needs no decoding, and keeps the system-prompt
    instructions and the rendered history in one consistent format. Histories
    whose arguments are all mappings still render as XML, byte-identically to
    tool_call_format='xml'.

    A caller that explicitly pins 'xml' still gets a hard error for string
    arguments, because that request cannot be honoured faithfully.
    ------------------------------------------------------------------------- -#}
{%- set format_scan = namespace(has_json_string_arguments=false) %}
{%- for message in messages %}
    {%- if message.role == 'assistant'
           and message.tool_calls is defined
           and message.tool_calls is not none
           and message.tool_calls
           and message.tool_calls is not string
           and message.tool_calls is not mapping
           and message.tool_calls is iterable %}
        {%- for tool_call in message.tool_calls %}
            {%- if tool_call.function is defined
                   and tool_call.function is not none %}
                {%- set _tc = tool_call.function %}
            {%- else %}
                {%- set _tc = tool_call %}
            {%- endif %}
            {%- if _tc.arguments is defined
                   and _tc.arguments is not none
                   and _tc.arguments is string
                   and _tc.arguments | trim
                   and _tc.arguments | trim != '{}' %}
                {%- set format_scan.has_json_string_arguments = true %}
            {%- endif %}
        {%- endfor %}
    {%- endif %}
{%- endfor %}
{%- if _requested_tool_format == 'auto' %}
    {%- if format_scan.has_json_string_arguments %}
        {%- set _tool_format = 'json' %}
    {%- else %}
        {%- set _tool_format = 'xml' %}
    {%- endif %}
{%- else %}
    {%- set _tool_format = _requested_tool_format %}
{%- endif %}
{%- set _thinking_enabled = enable_thinking %}
{%- if auto_disable_thinking_with_tools and _has_tools %}
    {%- set _thinking_enabled = false %}
{%- endif %}
{#- Validate reasoning effort even when thinking is disabled. -#}
{%- set _effort_raw =
    reasoning_effort if reasoning_effort is defined else 'xhigh'
%}
{%- if _effort_raw == 'high' or _effort_raw == 'xhigh' %}
    {%- set _reasoning_effort = 'xhigh' %}
{%- elif _effort_raw == 'medium' %}
    {%- set _reasoning_effort = 'medium' %}
{%- elif _effort_raw == 'low' %}
    {%- set _reasoning_effort = 'low' %}
{%- else %}
    {{- raise_exception(
        'Unexpected reasoning effort ' ~ _effort_raw ~
        '. Supported values are high/xhigh, medium, and low.'
    ) }}
{%- endif %}
{%- set reasoning_instructions = '' %}
{%- if _thinking_enabled %}
    {%- if _reasoning_effort == 'xhigh' %}
        {%- set reasoning_instructions =
            'Reasoning effort is set to xhigh. Please think carefully through the task, validate key assumptions, consider plausible alternatives, and prioritize correctness, consistency, and clarity in the final answer.'
        %}
    {%- elif _reasoning_effort == 'medium' %}
        {%- set reasoning_instructions =
            'Reasoning effort is set to medium. Balance accuracy and speed: use concise, task-focused reasoning and consider only what is necessary to choose the next correct action. Proceed once that action is clear.'
        %}
    {%- elif _reasoning_effort == 'low' %}
        {%- set reasoning_instructions =
            'Reasoning effort is set to low. Keep your thinking brief and focused, moving directly to the conclusion without unnecessary elaboration.'
        %}
    {%- endif %}
{%- endif %}
{#- -------------------------------------------------------------------------
    Content rendering
    ------------------------------------------------------------------------- -#}
{%- set image_count = namespace(value=0) %}
{%- set video_count = namespace(value=0) %}
{%- macro render_content(content, do_vision_count, is_system_content=false) %}
    {%- if content is string %}
        {{- content }}
    {%- elif content is iterable and content is not mapping %}
        {%- for item in content %}
            {%- if item is not mapping %}
                {{- raise_exception(
                    'Content-list items must be mappings with a supported text, image, or video type.'
                ) }}
            {%- endif %}
            {%- set _item_type = item.type if 'type' in item else none %}
            {%- if _item_type is not none
                   and _item_type not in ('text', 'image', 'image_url', 'video') %}
                {{- raise_exception(
                    'Unexpected content item type ' ~ _item_type ~ '.'
                ) }}
            {%- endif %}
            {%- set _is_image =
                _item_type == 'image'
                or _item_type == 'image_url'
                or 'image' in item
                or 'image_url' in item
            %}
            {%- set _is_video =
                _item_type == 'video'
                or 'video' in item
            %}
            {%- if _is_image and _is_video %}
                {{- raise_exception(
                    'A content item cannot contain both image and video data.'
                ) }}
            {%- elif _item_type == 'text' and (_is_image or _is_video) %}
                {{- raise_exception(
                    'A text content item cannot also contain image or video data.'
                ) }}
            {%- elif _is_image %}
                {%- if is_system_content %}
                    {{- raise_exception(
                        'System and developer messages cannot contain images.'
                    ) }}
                {%- endif %}
                {%- if do_vision_count %}
                    {%- set image_count.value = image_count.value + 1 %}
                {%- endif %}
                {%- if add_vision_id %}
                    {{- 'Picture ' ~ image_count.value ~ ': ' }}
                {%- endif %}
                {{- '<|vision_start|><|image_pad|><|vision_end|>' }}
            {%- elif _is_video %}
                {%- if is_system_content %}
                    {{- raise_exception(
                        'System and developer messages cannot contain videos.'
                    ) }}
                {%- endif %}
                {%- if do_vision_count %}
                    {%- set video_count.value = video_count.value + 1 %}
                {%- endif %}
                {%- if add_vision_id %}
                    {{- 'Video ' ~ video_count.value ~ ': ' }}
                {%- endif %}
                {{- '<|vision_start|><|video_pad|><|vision_end|>' }}
            {%- elif _item_type == 'text' or 'text' in item %}
                {%- if 'text' not in item or item.text is not string %}
                    {{- raise_exception(
                        'Text content items must contain a string text field.'
                    ) }}
                {%- endif %}
                {{- item.text }}
            {%- else %}
                {{- raise_exception(
                    'Unexpected item in content list. Expected text, image, or video content.'
                ) }}
            {%- endif %}
        {%- endfor %}
    {%- elif content is none or content is undefined %}
        {{- '' }}
    {%- else %}
        {{- raise_exception('Unexpected content type.') }}
    {%- endif %}
{%- endmacro %}
{#- -------------------------------------------------------------------------
    Validate and merge leading system/developer messages
    ------------------------------------------------------------------------- -#}
{%- set head = namespace(count=0, seen_non_system=false) %}
{%- for message in messages %}
    {%- set _is_system =
        message.role == 'system' or message.role == 'developer'
    %}
    {%- if _is_system %}
        {%- if head.seen_non_system %}
            {{- raise_exception(
                'System and developer messages must appear before all user, assistant, and tool messages.'
            ) }}
        {%- endif %}
        {%- set head.count = head.count + 1 %}
    {%- else %}
        {%- set head.seen_non_system = true %}
    {%- endif %}
{%- endfor %}
{%- set system_state = namespace(content='') %}
{%- for message in messages[:head.count] %}
    {%- set _part =
        render_content(message.content, false, true) | trim
    %}
    {%- if _part %}
        {%- if system_state.content %}
            {%- set system_state.content =
                system_state.content ~ '\n\n' ~ _part
            %}
        {%- else %}
            {%- set system_state.content = _part %}
        {%- endif %}
    {%- endif %}
{%- endfor %}
{%- set _system_content = system_state.content %}
{%- set _msgs = messages[head.count:] %}
{#- -------------------------------------------------------------------------
    System prompt and tool instructions
    ------------------------------------------------------------------------- -#}
{%- if _has_tools %}
    {{- '<|im_start|>system\n' }}
    {%- if reasoning_instructions %}
        {{- reasoning_instructions ~ '\n\n' }}
    {%- endif %}
    {{- '# Tools\n\nYou have access to the following functions:\n\n<tools>' }}
    {%- for tool in tools %}
        {{- '\n' }}
        {{- tool | tojson }}
    {%- endfor %}
    {{- '\n</tools>' }}
    {%- if _tool_format == 'json' %}
        {{- '\n\nIf you choose to call a function ONLY reply in the following format with NO suffix:\n\n<tool_call>\n{"name": "example_function_name", "arguments": {"example_parameter_1": "value_1", "example_parameter_2": "This is the value for the second parameter"}}\n</tool_call>\n\n<IMPORTANT>\nReminder:\n- Function calls MUST follow the specified format: a single JSON object with "name" and "arguments" keys must be nested within <tool_call></tool_call> XML tags\n- Required parameters MUST be specified\n- You may provide optional reasoning for your function call in natural language BEFORE the function call, but NOT after\n- If there is no function call available, answer the question like normal with your current knowledge and do not tell the user about function calls\n</IMPORTANT>' }}
    {%- else %}
        {{- '\n\nIf you choose to call a function ONLY reply in the following format with NO suffix:\n\n<tool_call>\n<function=example_function_name>\n<parameter=example_parameter_1>\nvalue_1\n</parameter>\n<parameter=example_parameter_2>\nThis is the value for the second parameter\nthat can span\nmultiple lines\n</parameter>\n</function>\n</tool_call>\n\n<IMPORTANT>\nReminder:\n- Function calls MUST follow the specified format: an inner <function=...></function> block must be nested within <tool_call></tool_call> XML tags\n- Required parameters MUST be specified\n- You may provide optional reasoning for your function call in natural language BEFORE the function call, but NOT after\n- If there is no function call available, answer the question like normal with your current knowledge and do not tell the user about function calls\n</IMPORTANT>' }}
    {%- endif %}
    {%- if _system_content %}
        {{- '\n\n' ~ _system_content }}
    {%- endif %}
    {{- '<|im_end|>\n' }}
{%- else %}
    {%- if _system_content %}
        {{- '<|im_start|>system\n'
            ~ (reasoning_instructions ~ '\n\n' if reasoning_instructions else '')
            ~ _system_content
            ~ '<|im_end|>\n'
        }}
    {%- elif reasoning_instructions %}
        {{- '<|im_start|>system\n'
            ~ reasoning_instructions
            ~ '<|im_end|>\n'
        }}
    {%- endif %}
{%- endif %}
{#- -------------------------------------------------------------------------
    Find the last real user query
    ------------------------------------------------------------------------- -#}
{%- set ns = namespace(
    multi_step_tool=true,
    last_query_index=(_msgs | length) - 1
) %}
{%- for message in _msgs[::-1] %}
    {%- set index = (_msgs | length - 1) - loop.index0 %}
    {%- if ns.multi_step_tool and message.role == 'user' %}
        {%- set _rendered_user =
            render_content(message.content, false) | trim
        %}
        {%- if not (
            _rendered_user.startswith('<tool_response>')
            and _rendered_user.endswith('</tool_response>')
        ) %}
            {%- set ns.multi_step_tool = false %}
            {%- set ns.last_query_index = index %}
        {%- endif %}
    {%- endif %}
{%- endfor %}
{%- if ns.multi_step_tool %}
    {{- raise_exception('No user query found in messages.') }}
{%- endif %}
{#- -------------------------------------------------------------------------
    Conversation rendering
    ------------------------------------------------------------------------- -#}
{%- set history_state = namespace(previous_role='') %}
{%- for message in _msgs %}
    {%- set content =
        render_content(message.content, true) | trim
    %}
    {%- if message.role == 'user' %}
        {{- '<|im_start|>user\n'
            ~ content
            ~ '<|im_end|>\n'
        }}
    {%- elif message.role == 'assistant' %}
        {%- set reasoning_content = '' %}
        {%- if message.reasoning_content is defined
               and message.reasoning_content is not none %}
            {%- if message.reasoning_content is string %}
                {%- set reasoning_content = message.reasoning_content %}
            {%- else %}
                {%- set reasoning_content =
                    message.reasoning_content | string
                %}
            {%- endif %}
        {%- elif message.thinking is defined
                 and message.thinking is not none %}
            {%- if message.thinking is string %}
                {%- set reasoning_content = message.thinking %}
            {%- else %}
                {%- set reasoning_content =
                    message.thinking | string
                %}
            {%- endif %}
        {%- endif %}
        {%- set reasoning_content = reasoning_content | trim %}
        {#- Preserve the original invariant: when thinking is preserved,
            always reconstruct the thinking block, even when it is empty. -#}
        {%- if _preserve_thinking
               or loop.index0 > ns.last_query_index %}
            {{- '<|im_start|>assistant\n<think>\n'
                ~ reasoning_content
                ~ '\n</think>\n\n'
                ~ content
            }}
        {%- else %}
            {{- '<|im_start|>assistant\n' ~ content }}
        {%- endif %}
        {%- if message.tool_calls is defined
               and message.tool_calls is not none
               and message.tool_calls %}
            {%- if message.tool_calls is string
                   or message.tool_calls is mapping
                   or message.tool_calls is not iterable %}
                {{- raise_exception(
                    'assistant.tool_calls must be an iterable list of tool calls.'
                ) }}
            {%- endif %}
            {%- for tool_call in message.tool_calls %}
                {%- if tool_call.function is defined
                       and tool_call.function is not none %}
                    {%- set tc = tool_call.function %}
                {%- else %}
                    {%- set tc = tool_call %}
                {%- endif %}
                {%- if tc.name is not defined
                       or tc.name is none
                       or tc.name is not string
                       or not tc.name %}
                    {{- raise_exception(
                        'Every tool call must have a non-empty string name.'
                    ) }}
                {%- endif %}
                {%- set tc_name = tc.name %}
                {%- if _tool_format == 'json' %}
                    {%- if loop.first %}
                        {%- if content | trim %}
                            {{- '\n\n<tool_call>\n' }}
                        {%- else %}
                            {{- '<tool_call>\n' }}
                        {%- endif %}
                    {%- else %}
                        {{- '\n<tool_call>\n' }}
                    {%- endif %}
                    {%- set _json_arguments = '{}' %}
                    {%- if tc.arguments is defined
                           and tc.arguments is not none %}
                        {%- if tc.arguments is mapping %}
                            {%- set _json_arguments =
                                tc.arguments | tojson
                            %}
                        {%- elif tc.arguments is string %}
                            {%- set _raw_arguments =
                                tc.arguments | trim
                            %}
                            {%- if _raw_arguments %}
                                {%- if not (
                                    _raw_arguments.startswith('{')
                                    and _raw_arguments.endswith('}')
                                ) %}
                                    {{- raise_exception(
                                        'JSON tool-call arguments must be a JSON object string.'
                                    ) }}
                                {%- endif %}
                                {%- set _json_arguments =
                                    _raw_arguments
                                %}
                            {%- endif %}
                        {%- else %}
                            {{- raise_exception(
                                'JSON tool-call arguments must be a mapping or a JSON object string.'
                            ) }}
                        {%- endif %}
                    {%- endif %}
                    {{- '{"name": ' }}
                    {{- tc_name | tojson }}
                    {{- ', "arguments": ' }}
                    {{- _json_arguments }}
                    {{- '}\n</tool_call>' }}
                {%- else %}
                    {%- if loop.first %}
                        {%- if content | trim %}
                            {{- '\n\n<tool_call>\n<function='
                                ~ tc_name
                                ~ '>\n'
                            }}
                        {%- else %}
                            {{- '<tool_call>\n<function='
                                ~ tc_name
                                ~ '>\n'
                            }}
                        {%- endif %}
                    {%- else %}
                        {{- '\n<tool_call>\n<function='
                            ~ tc_name
                            ~ '>\n'
                        }}
                    {%- endif %}
                    {%- if tc.arguments is defined
                           and tc.arguments is not none %}
                        {%- if tc.arguments is mapping %}
                            {%- for args_name, args_value
                                   in tc.arguments | items %}
                                {%- set _argument_name =
                                    args_name | string
                                %}
                                {{- '<parameter='
                                    ~ _argument_name
                                    ~ '>\n'
                                }}
                                {#- Preserve strings verbatim. Serialize every
                                    other type as JSON so booleans and null stay
                                    true/false/null instead of True/False/None. -#}
                                {%- if args_value is string %}
                                    {%- set _argument_value =
                                        args_value
                                    %}
                                {%- else %}
                                    {%- set _argument_value =
                                        args_value | tojson
                                    %}
                                {%- endif %}
                                {%- if max_tool_arg_chars > 0
                                       and _argument_value | length
                                           > max_tool_arg_chars %}
                                    {{- _argument_value[:max_tool_arg_chars] }}
                                    {{- '\n[TRUNCATED — original length '
                                        ~ (_argument_value | length | string)
                                        ~ ' chars]'
                                    }}
                                {%- else %}
                                    {{- _argument_value }}
                                {%- endif %}
                                {{- '\n</parameter>\n' }}
                            {%- endfor %}
                        {%- elif tc.arguments is string %}
                            {%- set _raw_arguments =
                                tc.arguments | trim
                            %}
                            {%- if _raw_arguments
                                   and _raw_arguments != '{}' %}
                                {{- raise_exception(
                                    'tool_call_format="xml" requires tool-call arguments to be mappings, but received a JSON string. Parse the JSON string into a mapping before applying the template, or leave tool_call_format unset so the template can select the JSON tool-call format automatically.'
                                ) }}
                            {%- endif %}
                        {%- else %}
                            {{- raise_exception(
                                'XML tool-call arguments must be a mapping. Parse JSON-string arguments before applying the template.'
                            ) }}
                        {%- endif %}
                    {%- endif %}
                    {{- '</function>\n</tool_call>' }}
                {%- endif %}
            {%- endfor %}
        {%- endif %}
        {{- '<|im_end|>\n' }}
    {%- elif message.role == 'tool' %}
        {%- if history_state.previous_role != 'tool' %}
            {{- '<|im_start|>user' }}
        {%- endif %}
        {%- if max_tool_response_chars > 0
               and content | length > max_tool_response_chars %}
            {%- set content =
                content[:max_tool_response_chars]
                ~ '\n[TRUNCATED — original length '
                ~ (content | length | string)
                ~ ' chars]'
            %}
        {%- endif %}
        {{- '\n<tool_response>\n' }}
        {{- content }}
        {{- '\n</tool_response>' }}
        {%- if loop.last %}
            {{- '<|im_end|>\n' }}
        {%- elif _msgs[loop.index0 + 1].role != 'tool' %}
            {{- '<|im_end|>\n' }}
        {%- endif %}
    {%- elif message.role == 'system'
             or message.role == 'developer' %}
        {{- raise_exception(
            'System and developer messages must appear only at the beginning of the conversation.'
        ) }}
    {%- else %}
        {{- raise_exception(
            'Unexpected message role ' ~ message.role ~ '.'
        ) }}
    {%- endif %}
    {%- set history_state.previous_role = message.role %}
{%- endfor %}
{#- -------------------------------------------------------------------------
    Generation prompt
    ------------------------------------------------------------------------- -#}
{%- if add_generation_prompt %}
    {{- '<|im_start|>assistant\n' }}
    {%- if not _thinking_enabled %}
        {{- '<think>\n\n</think>\n\n' }}
    {%- else %}
        {{- '<think>\n' }}
    {%- endif %}
{%- endif %}