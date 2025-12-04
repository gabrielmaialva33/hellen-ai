# Charts Component Usage Guide

This guide demonstrates how to use the ApexCharts integration in Hellen AI's Phoenix LiveView application.

## Overview

The Charts component provides easy-to-use, interactive charts powered by ApexCharts with full LiveView integration and dark mode support.

## Available Components

### 1. Generic Chart Component

The base chart component supports all ApexCharts types.

```elixir
<.chart
  id="my-chart"
  type="line"
  series={[%{name: "Sales", data: [30, 40, 35, 50, 49, 60, 70]}]}
  categories={["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul"]}
  title="Monthly Sales"
  height="350"
  colors={["#4f46e5"]}
  show_toolbar={false}
/>
```

**Attributes:**
- `id` (required): Unique identifier for the chart
- `type`: Chart type - `line`, `bar`, `area`, `donut`, `radialBar`, `pie` (default: `line`)
- `series` (required): Chart data array
- `categories`: X-axis categories (for line/bar/area charts)
- `labels`: Labels for donut/pie charts
- `height`: Chart height in pixels (default: `350`)
- `colors`: Array of hex colors (default: indigo, green, yellow, red, purple, pink)
- `title`: Chart title
- `show_toolbar`: Show/hide chart toolbar (default: `false`)
- `show_legend`: Show/hide legend (default: `true`)
- `class`: Additional CSS classes

### 2. Score Gauge

Displays a radial gauge for scores, automatically colored based on value.

```elixir
<.score_gauge
  id="lesson-score"
  score={85}
  label="Overall Score"
/>
```

**Color scheme:**
- Green (#22c55e): 80-100
- Yellow (#eab308): 60-79
- Red (#ef4444): 0-59

### 3. Comparison Chart

Horizontal bar chart for comparing multiple values.

```elixir
<.comparison_chart
  id="subject-comparison"
  categories={["Mathematics", "Science", "History"]}
  data={[85, 92, 78]}
  title="Performance by Subject"
/>
```

### 4. Trend Chart

Area chart for showing trends over time.

```elixir
<.trend_chart
  id="weekly-trend"
  categories={["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]}
  data={[12, 19, 15, 25, 22, 18, 20]}
  label="Lessons Created"
  title="Weekly Activity"
  height="300"
/>
```

## Chart Types Examples

### Line Chart

```elixir
<.chart
  id="temperature-line"
  type="line"
  series={[
    %{name: "High", data: [28, 29, 33, 36, 32, 32, 33]},
    %{name: "Low", data: [12, 11, 14, 18, 17, 13, 13]}
  ]}
  categories={["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]}
/>
```

### Bar Chart

```elixir
<.chart
  id="sales-bar"
  type="bar"
  series={[%{name: "Sales", data: [44, 55, 57, 56, 61, 58]}]}
  categories={["Q1", "Q2", "Q3", "Q4", "Q5", "Q6"]}
  colors={["#4f46e5"]}
/>
```

### Donut Chart

```elixir
<.chart
  id="status-donut"
  type="donut"
  series={[44, 55, 13, 33]}
  labels={["Completed", "In Progress", "Pending", "Failed"]}
  colors={["#22c55e", "#3b82f6", "#eab308", "#ef4444"]}
/>
```

### Pie Chart

```elixir
<.chart
  id="distribution-pie"
  type="pie"
  series={[25, 35, 40]}
  labels={["Mobile", "Desktop", "Tablet"]}
/>
```

## LiveView Integration

### Dynamic Updates

You can update chart data dynamically from your LiveView:

```elixir
# In your LiveView mount or handle_event
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:chart_data, [10, 20, 30, 40])
   |> assign(:chart_categories, ["A", "B", "C", "D"])}
end

# In your template
<.chart
  id="dynamic-chart"
  type="line"
  series={[%{name: "Values", data: @chart_data}]}
  categories={@chart_categories}
/>
```

When you update the assigns, the chart will automatically re-render:

```elixir
def handle_event("refresh_data", _params, socket) do
  new_data = fetch_new_data()
  {:noreply, assign(socket, :chart_data, new_data)}
end
```

### Server-Side Events

You can also push updates via server events:

```elixir
# Push series update
push_event(socket, "chart-update", %{
  series: [%{name: "New Data", data: [5, 10, 15, 20]}]
})

# Push options update
push_event(socket, "chart-options", %{
  options: %{title: %{text: "Updated Title"}}
})
```

## Dark Mode Support

Charts automatically adapt to dark mode. The theme is applied based on the presence of the `dark` class on `document.documentElement`.

The ChartHook listens for `theme-changed` events:

```javascript
window.dispatchEvent(new CustomEvent("theme-changed", {
  detail: { theme: "dark" }
}))
```

## Responsive Design

All charts are responsive by default. They automatically adjust to their container width.

```elixir
<div class="grid gap-6 lg:grid-cols-2">
  <.card>
    <.chart id="chart1" type="line" series={@series1} categories={@cats1} />
  </.card>
  <.card>
    <.chart id="chart2" type="donut" series={@series2} labels={@labels2} />
  </.card>
</div>
```

## Best Practices

1. **Unique IDs**: Always use unique IDs for each chart instance
2. **Empty Data**: Handle empty data gracefully in your LiveView
3. **Performance**: For large datasets, consider using `phx-update="ignore"` (already applied)
4. **Colors**: Use the default color palette for consistency, or customize to match your brand
5. **Height**: Adjust chart height based on the container and data density

## Example: Dashboard with Statistics

```elixir
defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    stats = calculate_stats()

    {:ok,
     socket
     |> assign(:stats, stats)
     |> assign(:weekly_data, get_weekly_data())
     |> assign(:status_counts, get_status_counts())}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="grid gap-6 lg:grid-cols-2">
        <.card>
          <:header>Weekly Trend</:header>
          <.trend_chart
            id="weekly-trend"
            categories={@weekly_data.dates}
            data={@weekly_data.counts}
            label="Lessons"
            height="300"
          />
        </.card>

        <.card>
          <:header>Status Distribution</:header>
          <.chart
            id="status-distribution"
            type="donut"
            series={@status_counts.values}
            labels={@status_counts.labels}
            height="300"
          />
        </.card>
      </div>

      <.card>
        <:header>Performance Score</:header>
        <div class="flex justify-center">
          <.score_gauge
            id="performance-score"
            score={@stats.average_score}
            label="Average Performance"
          />
        </div>
      </.card>
    </div>
    """
  end
end
```

## Troubleshooting

### Chart Not Rendering

1. Ensure ApexCharts is loaded (check browser console)
2. Verify the hook is registered in `app.js`
3. Check that the chart ID is unique
4. Validate that series data is properly formatted

### Dark Mode Not Working

1. Verify the `dark` class is on `document.documentElement`
2. Check that theme-changed events are being dispatched
3. Ensure Tailwind dark mode is configured

### Update Not Reflecting

1. Remember that charts use `phx-update="ignore"` by default
2. To update, change the data in assigns - the component will re-render
3. Or use push_event for real-time updates without full re-render

## API Reference

For full ApexCharts API documentation, visit: https://apexcharts.com/docs/
