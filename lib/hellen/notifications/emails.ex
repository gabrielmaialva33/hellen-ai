defmodule Hellen.Notifications.Emails do
  @moduledoc """
  Email templates for notifications.
  """
  import Swoosh.Email

  @from_address {"Hellen AI", "noreply@hellen.ai"}
  @alerts_address {"Hellen AI Alertas", "alertas@hellen.ai"}

  @doc "Build email for alert notification"
  def alert_email(user, notification) do
    alert_data = notification.data || %{}

    new()
    |> to({user.name || user.email, user.email})
    |> from(@alerts_address)
    |> subject(alert_subject(notification.type, alert_data))
    |> html_body(alert_html(user, notification, alert_data))
    |> text_body(alert_text(user, notification, alert_data))
  end

  @doc "Build email for analysis complete notification"
  def analysis_complete_email(user, notification) do
    data = notification.data || %{}

    new()
    |> to({user.name || user.email, user.email})
    |> from(@from_address)
    |> subject("Analise Concluida - #{data["lesson_title"] || "Aula"}")
    |> html_body(analysis_complete_html(user, notification, data))
    |> text_body(analysis_complete_text(user, notification, data))
  end

  @doc "Build email for weekly summary"
  def weekly_summary_email(user, stats) do
    new()
    |> to({user.name || user.email, user.email})
    |> from(@from_address)
    |> subject("Resumo Semanal - Hellen AI")
    |> html_body(weekly_summary_html(user, stats))
    |> text_body(weekly_summary_text(user, stats))
  end

  @doc "Build the appropriate email based on notification type"
  def build_email(notification, user) do
    case notification.type do
      type when type in ~w(alert_critical alert_high) ->
        alert_email(user, notification)

      "analysis_complete" ->
        analysis_complete_email(user, notification)

      "weekly_summary" ->
        weekly_summary_email(user, notification.data)

      _ ->
        nil
    end
  end

  # Private helpers

  defp alert_subject("alert_critical", data) do
    "[URGENTE] Alerta Critico - #{alert_type_label(data["alert_type"])}"
  end

  defp alert_subject("alert_high", data) do
    "[Alerta] #{alert_type_label(data["alert_type"])} Detectado"
  end

  defp alert_subject(_type, data) do
    "Alerta - #{alert_type_label(data["alert_type"])}"
  end

  defp alert_type_label("verbal_aggression"), do: "Agressao Verbal"
  defp alert_type_label("exclusion"), do: "Exclusao"
  defp alert_type_label("intimidation"), do: "Intimidacao"
  defp alert_type_label("mockery"), do: "Zombaria"
  defp alert_type_label("discrimination"), do: "Discriminacao"
  defp alert_type_label("threat"), do: "Ameaca"
  defp alert_type_label("inappropriate_language"), do: "Linguagem Inapropriada"
  defp alert_type_label(_), do: "Comportamento Inadequado"

  defp severity_color("critical"), do: "#dc2626"
  defp severity_color("high"), do: "#ea580c"
  defp severity_color("medium"), do: "#ca8a04"
  defp severity_color(_), do: "#6b7280"

  defp alert_html(user, notification, data) do
    severity = data["severity"] || "medium"

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        body { font-family: 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #{severity_color(severity)}; color: white; padding: 20px; border-radius: 8px 8px 0 0; }
        .content { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px; }
        .alert-box { background: white; border-left: 4px solid #{severity_color(severity)}; padding: 15px; margin: 15px 0; }
        .footer { margin-top: 20px; padding-top: 20px; border-top: 1px solid #e5e7eb; font-size: 12px; color: #6b7280; }
        .btn { display: inline-block; background: #4f46e5; color: white; padding: 10px 20px; border-radius: 6px; text-decoration: none; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1 style="margin: 0; font-size: 20px;">#{notification.title}</h1>
        </div>
        <div class="content">
          <p>Ola, #{user.name || "Professor(a)"}!</p>
          <p>#{notification.message}</p>

          <div class="alert-box">
            <p><strong>Tipo:</strong> #{alert_type_label(data["alert_type"])}</p>
            <p><strong>Severidade:</strong> #{String.capitalize(severity)}</p>
            #{if data["lesson_title"], do: "<p><strong>Aula:</strong> #{data["lesson_title"]}</p>", else: ""}
            #{if data["evidence_text"], do: "<p><strong>Evidencia:</strong> \"#{data["evidence_text"]}\"</p>", else: ""}
          </div>

          <p>
            <a href="#{data["alert_url"] || "#"}" class="btn">Ver Detalhes</a>
          </p>

          <div class="footer">
            <p>Este email foi enviado automaticamente pelo sistema Hellen AI.</p>
            <p>Conforme a Lei 13.185/2015 (Programa de Combate ao Bullying), alertas de comportamento inadequado devem ser tratados com prioridade.</p>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp alert_text(user, notification, data) do
    """
    #{notification.title}

    Ola, #{user.name || "Professor(a)"}!

    #{notification.message}

    Tipo: #{alert_type_label(data["alert_type"])}
    Severidade: #{data["severity"] || "medium"}
    #{if data["lesson_title"], do: "Aula: #{data["lesson_title"]}", else: ""}
    #{if data["evidence_text"], do: "Evidencia: \"#{data["evidence_text"]}\"", else: ""}

    --
    Este email foi enviado automaticamente pelo sistema Hellen AI.
    """
  end

  defp analysis_complete_html(user, _notification, data) do
    score = data["score"] || 0

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        body { font-family: 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #4f46e5; color: white; padding: 20px; border-radius: 8px 8px 0 0; }
        .content { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px; }
        .score { font-size: 48px; font-weight: bold; color: #4f46e5; text-align: center; }
        .footer { margin-top: 20px; font-size: 12px; color: #6b7280; }
        .btn { display: inline-block; background: #4f46e5; color: white; padding: 10px 20px; border-radius: 6px; text-decoration: none; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1 style="margin: 0; font-size: 20px;">Analise Concluida</h1>
        </div>
        <div class="content">
          <p>Ola, #{user.name || "Professor(a)"}!</p>
          <p>A analise da sua aula <strong>#{data["lesson_title"] || "Aula"}</strong> foi concluida.</p>

          <div class="score">#{Float.round(score / 1, 1)}</div>
          <p style="text-align: center; color: #6b7280;">Score Pedagogico</p>

          <p style="text-align: center;">
            <a href="#{data["analysis_url"] || "#"}" class="btn">Ver Analise Completa</a>
          </p>

          <div class="footer">
            <p>Este email foi enviado automaticamente pelo sistema Hellen AI.</p>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp analysis_complete_text(user, _notification, data) do
    """
    Analise Concluida

    Ola, #{user.name || "Professor(a)"}!

    A analise da sua aula "#{data["lesson_title"] || "Aula"}" foi concluida.

    Score Pedagogico: #{data["score"] || 0}

    Acesse a plataforma para ver a analise completa.

    --
    Este email foi enviado automaticamente pelo sistema Hellen AI.
    """
  end

  defp weekly_summary_html(user, stats) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        body { font-family: 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #4f46e5; color: white; padding: 20px; border-radius: 8px 8px 0 0; }
        .content { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px; }
        .stats-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 15px; margin: 20px 0; }
        .stat-card { background: white; padding: 15px; border-radius: 8px; text-align: center; }
        .stat-value { font-size: 32px; font-weight: bold; color: #4f46e5; }
        .stat-label { font-size: 14px; color: #6b7280; }
        .footer { margin-top: 20px; font-size: 12px; color: #6b7280; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1 style="margin: 0; font-size: 20px;">Resumo Semanal</h1>
        </div>
        <div class="content">
          <p>Ola, #{user.name || "Usuario"}!</p>
          <p>Confira o resumo da ultima semana:</p>

          <div class="stats-grid">
            <div class="stat-card">
              <div class="stat-value">#{stats["lessons"] || 0}</div>
              <div class="stat-label">Aulas</div>
            </div>
            <div class="stat-card">
              <div class="stat-value">#{stats["analyses"] || 0}</div>
              <div class="stat-label">Analises</div>
            </div>
            <div class="stat-card">
              <div class="stat-value">#{stats["alerts"] || 0}</div>
              <div class="stat-label">Alertas</div>
            </div>
            <div class="stat-card">
              <div class="stat-value">#{stats["avg_score"] || "-"}</div>
              <div class="stat-label">Score Medio</div>
            </div>
          </div>

          <div class="footer">
            <p>Este email foi enviado automaticamente pelo sistema Hellen AI.</p>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp weekly_summary_text(user, stats) do
    """
    Resumo Semanal - Hellen AI

    Ola, #{user.name || "Usuario"}!

    Confira o resumo da ultima semana:

    - Aulas: #{stats["lessons"] || 0}
    - Analises: #{stats["analyses"] || 0}
    - Alertas: #{stats["alerts"] || 0}
    - Score Medio: #{stats["avg_score"] || "-"}

    --
    Este email foi enviado automaticamente pelo sistema Hellen AI.
    """
  end
end
