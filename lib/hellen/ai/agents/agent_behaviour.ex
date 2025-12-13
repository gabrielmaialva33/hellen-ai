defmodule Hellen.AI.Agents.AgentBehaviour do
  @moduledoc """
  Common behaviour for all analysis SubAgents.

  Each SubAgent is a specialized GenServer that:
  - Processes a specific aspect of the lesson analysis
  - Uses a designated AI model for its task
  - Reports progress via PubSub
  - Returns structured results

  ## Implementing an Agent

      defmodule MyAgent do
        @behaviour Hellen.AI.Agents.AgentBehaviour
        use Hellen.AI.Agents.AgentBase

        @impl true
        def model, do: "meta/llama-3.1-70b-instruct"

        @impl true
        def task_name, do: "my_task"

        @impl true
        def process(input, context) do
          # Your processing logic here
          {:ok, result}
        end
      end
  """

  @doc "Returns the AI model ID to use for this agent"
  @callback model() :: String.t()

  @doc "Returns a human-readable task name"
  @callback task_name() :: String.t()

  @doc "Returns task description for UI display"
  @callback task_description() :: String.t()

  @doc "Processes the input and returns a result"
  @callback process(input :: any(), context :: map()) :: {:ok, any()} | {:error, any()}

  @doc "Returns the prompt template for this agent's task"
  @callback build_prompt(input :: any(), context :: map()) :: String.t()
end

defmodule Hellen.AI.Agents.AgentBase do
  @moduledoc """
  Base module that provides common functionality for all SubAgents.

  Use this module in your agent implementations:

      defmodule Hellen.AI.Agents.MyAgent do
        use Hellen.AI.Agents.AgentBase
        @behaviour Hellen.AI.Agents.AgentBehaviour

        # ... implement callbacks
      end
  """

  defmacro __using__(_opts) do
    quote do
      use GenServer
      require Logger

      alias Hellen.AI.ProcessingStatus

      @nvidia_url "https://integrate.api.nvidia.com/v1/chat/completions"

      # ============================================================================
      # GenServer Client API
      # ============================================================================

      def start_link(opts \\ []) do
        name = Keyword.get(opts, :name, __MODULE__)
        GenServer.start_link(__MODULE__, opts, name: name)
      end

      def run(input, context \\ %{}, opts \\ []) do
        timeout = Keyword.get(opts, :timeout, 300_000)

        case Keyword.get(opts, :async, false) do
          true ->
            Task.async(fn -> do_process(input, context) end)

          false ->
            do_process(input, context)
        end
      end

      # ============================================================================
      # GenServer Callbacks
      # ============================================================================

      @impl GenServer
      def init(opts) do
        {:ok, %{opts: opts}}
      end

      @impl GenServer
      def handle_call({:process, input, context}, _from, state) do
        result = do_process(input, context)
        {:reply, result, state}
      end

      @impl GenServer
      def handle_cast({:process_async, input, context, reply_to}, state) do
        result = do_process(input, context)
        send(reply_to, {:agent_result, __MODULE__, result})
        {:noreply, state}
      end

      # ============================================================================
      # Processing Logic
      # ============================================================================

      defp do_process(input, context) do
        lesson_id = context[:lesson_id]
        start_time = System.monotonic_time(:millisecond)

        # Notify start
        if lesson_id do
          ProcessingStatus.update(lesson_id, String.to_atom(task_name()), %{
            model: model(),
            status: :running,
            message: task_description()
          })
        end

        Logger.info("[#{__MODULE__}] Starting #{task_name()} with model #{model()}")

        # Build prompt and call API
        prompt = build_prompt(input, context)
        result = call_model(prompt, context)

        processing_time = System.monotonic_time(:millisecond) - start_time

        # Notify completion
        case result do
          {:ok, data} ->
            if lesson_id do
              ProcessingStatus.complete(lesson_id, String.to_atom(task_name()), %{
                duration_ms: processing_time,
                model_id: model()
              })
            end

            Logger.info("[#{__MODULE__}] Completed #{task_name()} in #{processing_time}ms")
            {:ok, Map.put(data, :processing_time_ms, processing_time)}

          {:error, reason} = error ->
            if lesson_id do
              ProcessingStatus.fail(lesson_id, String.to_atom(task_name()), inspect(reason))
            end

            Logger.error("[#{__MODULE__}] Failed #{task_name()}: #{inspect(reason)}")
            error
        end
      end

      defp call_model(prompt, context) do
        api_key = Application.get_env(:hellen, :nvidia_api_key)
        temperature = context[:temperature] || 0.5
        max_tokens = context[:max_tokens] || 4096

        headers = [
          {"Authorization", "Bearer #{api_key}"},
          {"Content-Type", "application/json"}
        ]

        body = %{
          "model" => model(),
          "messages" => [
            %{"role" => "user", "content" => prompt}
          ],
          "temperature" => temperature,
          "max_tokens" => max_tokens,
          "response_format" => %{"type" => "json_object"}
        }

        @nvidia_url
        |> Req.post(json: body, headers: headers, receive_timeout: 300_000)
        |> handle_api_response()
      end

      defp handle_api_response({:ok, %{status: 200, body: response_body}}) do
        message = get_in(response_body, ["choices", Access.at(0), "message", "content"])
        usage = response_body["usage"] || %{}
        parsed = parse_json_response(message)

        {:ok,
         %{
           result: parsed,
           model: model(),
           tokens_used: (usage["prompt_tokens"] || 0) + (usage["completion_tokens"] || 0)
         }}
      end

      defp handle_api_response({:ok, %{status: status, body: body}}) do
        {:error, {:api_error, status, body}}
      end

      defp handle_api_response({:error, reason}) do
        {:error, {:request_failed, reason}}
      end

      defp parse_json_response(message) do
        case Jason.decode(message) do
          {:ok, data} -> data
          {:error, _} -> %{"raw" => message}
        end
      end

      # Allow overriding in implementations
      defoverridable [run: 3, do_process: 2]
    end
  end
end
