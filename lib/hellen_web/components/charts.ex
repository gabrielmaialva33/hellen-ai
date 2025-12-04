defmodule HellenWeb.Components.Charts do
  @moduledoc """
  Chart components using ApexCharts with LiveView integration.
  """
  use Phoenix.Component

  @doc """
  Renders an ApexCharts chart with LiveView integration.

  ## Examples

      <.chart
        id="lesson-scores"
        type="line"
        series={[%{name: "Score", data: [65, 72, 80, 75, 90]}]}
        categories={["Aula 1", "Aula 2", "Aula 3", "Aula 4", "Aula 5"]}
      />

      <.chart
        id="status-breakdown"
        type="donut"
        series={[10, 5, 2]}
        labels={["Concluídas", "Em Progresso", "Pendentes"]}
      />
  """
  attr :id, :string, required: true
  attr :type, :string, default: "line", values: ~w(line bar area donut radialBar pie)
  attr :series, :list, required: true
  attr :categories, :list, default: []
  attr :labels, :list, default: []
  attr :height, :string, default: "350"
  attr :colors, :list, default: ["#4f46e5", "#22c55e", "#eab308", "#ef4444", "#8b5cf6", "#ec4899"]
  attr :class, :string, default: ""
  attr :title, :string, default: nil
  attr :show_toolbar, :boolean, default: false
  attr :show_legend, :boolean, default: true

  def chart(assigns) do
    options = build_chart_options(assigns)
    assigns = assign(assigns, :options_json, Jason.encode!(options))

    ~H"""
    <div
      id={@id}
      phx-hook="ChartHook"
      phx-update="ignore"
      data-chart-options={@options_json}
      class={["w-full", @class]}
      style={"min-height: #{@height}px"}
    />
    """
  end

  defp build_chart_options(assigns) do
    base_options = %{
      chart: %{
        type: assigns.type,
        height: assigns.height,
        toolbar: %{show: assigns.show_toolbar},
        animations: %{enabled: true, speed: 500}
      },
      series: assigns.series,
      colors: assigns.colors,
      stroke: %{curve: "smooth", width: 2},
      dataLabels: %{enabled: false},
      legend: %{show: assigns.show_legend}
    }

    base_options
    |> maybe_add_categories(assigns)
    |> maybe_add_labels(assigns)
    |> maybe_add_title(assigns)
    |> add_type_specific_options(assigns.type)
  end

  defp maybe_add_categories(options, %{categories: []}), do: options

  defp maybe_add_categories(options, %{categories: categories}) do
    put_in(options, [:xaxis], %{categories: categories})
  end

  defp maybe_add_labels(options, %{labels: []}), do: options

  defp maybe_add_labels(options, %{labels: labels}) do
    put_in(options, [:labels], labels)
  end

  defp maybe_add_title(options, %{title: nil}), do: options

  defp maybe_add_title(options, %{title: title}) do
    put_in(options, [:title], %{text: title, align: "left"})
  end

  defp add_type_specific_options(options, "donut") do
    Map.merge(options, %{
      plotOptions: %{
        pie: %{donut: %{size: "70%"}}
      },
      legend: %{position: "bottom"}
    })
  end

  defp add_type_specific_options(options, "pie") do
    Map.merge(options, %{
      legend: %{position: "bottom"}
    })
  end

  defp add_type_specific_options(options, "radialBar") do
    Map.merge(options, %{
      plotOptions: %{
        radialBar: %{
          hollow: %{size: "60%"},
          dataLabels: %{
            name: %{fontSize: "14px"},
            value: %{fontSize: "24px", fontWeight: 700}
          }
        }
      }
    })
  end

  defp add_type_specific_options(options, _type), do: options

  @doc """
  Renders a score gauge chart (radialBar) for displaying analysis scores.

  ## Examples

      <.score_gauge id="overall-score" score={85} label="Overall Score" />
  """
  attr :id, :string, required: true
  attr :score, :integer, required: true
  attr :label, :string, default: "Score"
  attr :class, :string, default: ""

  def score_gauge(assigns) do
    assigns = assign(assigns, :color, score_color(assigns.score))

    ~H"""
    <.chart
      id={@id}
      type="radialBar"
      series={[@score]}
      labels={[@label]}
      colors={[@color]}
      height="200"
      show_legend={false}
      class={@class}
    />
    """
  end

  defp score_color(score) when score >= 80, do: "#22c55e"
  defp score_color(score) when score >= 60, do: "#eab308"
  defp score_color(_score), do: "#ef4444"

  @doc """
  Renders a horizontal bar chart for comparing values.

  ## Examples

      <.comparison_chart
        id="subject-comparison"
        categories={["Matemática", "Português", "História"]}
        data={[85, 72, 90]}
      />
  """
  attr :id, :string, required: true
  attr :categories, :list, required: true
  attr :data, :list, required: true
  attr :title, :string, default: nil
  attr :class, :string, default: ""

  def comparison_chart(assigns) do
    ~H"""
    <.chart
      id={@id}
      type="bar"
      series={[%{name: "Pontuação", data: @data}]}
      categories={@categories}
      title={@title}
      colors={["#4f46e5"]}
      class={@class}
    />
    """
  end

  @doc """
  Renders a line chart showing trends over time.

  ## Examples

      <.trend_chart
        id="weekly-trend"
        categories={["Seg", "Ter", "Qua", "Qui", "Sex"]}
        data={[65, 72, 68, 80, 75]}
        label="Pontuação Média"
      />
  """
  attr :id, :string, required: true
  attr :categories, :list, required: true
  attr :data, :list, required: true
  attr :label, :string, default: "Valor"
  attr :title, :string, default: nil
  attr :height, :string, default: "350"
  attr :class, :string, default: ""

  def trend_chart(assigns) do
    ~H"""
    <.chart
      id={@id}
      type="area"
      series={[%{name: @label, data: @data}]}
      categories={@categories}
      title={@title}
      height={@height}
      colors={["#4f46e5"]}
      class={@class}
    />
    """
  end
end
