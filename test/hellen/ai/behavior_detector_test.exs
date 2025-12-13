defmodule Hellen.AI.BehaviorDetectorTest do
  use ExUnit.Case, async: true

  alias Hellen.AI.BehaviorDetector

  describe "detect_sarcasm/1" do
    test "detects 'Só X?' pattern" do
      result = BehaviorDetector.detect_sarcasm("Só sim? É isso que você tem pra dizer?")

      assert result.detected == true
      assert result.severity == :high
      assert result.score_impact < 0
      assert not Enum.empty?(result.evidence)
    end

    test "detects 'Você tem essa mania' pattern" do
      result = BehaviorDetector.detect_sarcasm("Você tem essa mania de fazer isso toda hora.")

      assert result.detected == true
      assert result.severity == :critical
      assert result.score_impact <= -15
    end

    test "detects 'Claro, né' dismissive pattern" do
      result = BehaviorDetector.detect_sarcasm("Claro, né. Sempre a mesma coisa.")

      assert result.detected == true
      assert result.severity in [:high, :medium]
    end

    test "detects 'Até criança sabe' derogatory comparison" do
      result = BehaviorDetector.detect_sarcasm("Até criança sabe fazer isso direito.")

      assert result.detected == true
      assert result.severity == :critical
    end

    test "detects multiple sarcasm patterns" do
      text = "Só isso? Claro, né. Você tem essa mania de sempre errar."
      result = BehaviorDetector.detect_sarcasm(text)

      assert result.detected == true
      assert result.severity == :critical
      assert length(result.evidence) >= 2
      assert result.score_impact <= -20
    end

    test "returns no detection for neutral text" do
      result = BehaviorDetector.detect_sarcasm("Muito bem! Vocês estão progredindo bastante.")

      assert result.detected == false
      assert result.severity == :none
      assert result.score_impact == 0
    end

    test "handles empty string" do
      result = BehaviorDetector.detect_sarcasm("")

      assert result.detected == false
    end
  end

  describe "detect_disengagement/1" do
    test "detects sleeping student" do
      result = BehaviorDetector.detect_disengagement("Ivã dormiu de novo durante a aula.")

      assert result.detected == true
      assert result.severity == :critical
    end

    test "detects teacher waking student" do
      result = BehaviorDetector.detect_disengagement("Acorda o João, ele está dormindo.")

      assert result.detected == true
      assert result.severity == :critical
    end

    test "detects missing student" do
      result = BehaviorDetector.detect_disengagement("Cadê o Pedro? Não sei onde está.")

      assert result.detected == true
      assert result.severity == :high
    end

    test "detects explicit resistance" do
      result = BehaviorDetector.detect_disengagement("Eu não quero mais fazer isso.")

      assert result.detected == true
      assert result.severity == :high
    end

    test "detects general silence" do
      result = BehaviorDetector.detect_disengagement("Ninguém responde? Silêncio total?")

      assert result.detected == true
      assert result.severity == :medium
    end

    test "detects cellphone distraction" do
      result = BehaviorDetector.detect_disengagement("Para de mexer no celular!")

      assert result.detected == true
      assert result.severity == :medium
    end

    test "returns no detection for engaged class" do
      result =
        BehaviorDetector.detect_disengagement("Todo mundo participando, muito bem!")

      assert result.detected == false
    end
  end

  describe "detect_public_shame/1" do
    test "detects body odor comment" do
      result = BehaviorDetector.detect_public_shame("Perfume, você me cheirou assim?")

      assert result.detected == true
      assert result.severity == :critical
    end

    test "detects public exposure of mistake" do
      result =
        BehaviorDetector.detect_public_shame("Olha o que o João fez, classe! Todo mundo viu?")

      assert result.detected == true
      # "todo mundo viu/sabe" is :high, which is still problematic
      assert result.severity in [:critical, :high]
    end

    test "detects academic shaming" do
      result =
        BehaviorDetector.detect_public_shame("Todo mundo acertou menos você, Maria.")

      assert result.detected == true
      assert result.severity == :critical
    end

    test "detects isolation by performance" do
      result = BehaviorDetector.detect_public_shame("Só você não conseguiu resolver.")

      assert result.detected == true
      assert result.severity == :critical
    end

    test "detects laughter context" do
      result = BehaviorDetector.detect_public_shame("(risos) Engraçado, né?")

      assert result.detected == true
      assert result.severity == :medium
    end

    test "returns no detection for positive feedback" do
      result =
        BehaviorDetector.detect_public_shame("Parabéns a todos pelo excelente trabalho!")

      assert result.detected == false
    end
  end

  describe "detect_exclusion/1" do
    test "detects exclusion from activity" do
      result = BehaviorDetector.detect_exclusion("Você não pode participar dessa atividade.")

      assert result.detected == true
      assert result.severity == :critical
    end

    test "detects group expulsion" do
      result = BehaviorDetector.detect_exclusion("Sai do grupo, não queremos você aqui.")

      assert result.detected == true
      assert result.severity == :critical
    end

    test "detects forced isolation" do
      result = BehaviorDetector.detect_exclusion("Fica aí sozinho no canto.")

      assert result.detected == true
      assert result.severity == :high
    end

    test "detects social rejection" do
      result = BehaviorDetector.detect_exclusion("Ninguém quer você no time.")

      assert result.detected == true
      assert result.severity == :critical
    end

    test "returns no detection for inclusive text" do
      result = BehaviorDetector.detect_exclusion("Vamos todos juntos fazer essa atividade.")

      assert result.detected == false
    end
  end

  describe "detect_aggression/1" do
    test "detects direct insult" do
      result = BehaviorDetector.detect_aggression("Você é burro demais!")

      assert result.detected == true
      assert result.severity == :critical
      assert result.score_impact <= -20
    end

    test "detects aggressive command" do
      result = BehaviorDetector.detect_aggression("Cala a boca agora!")

      assert result.detected == true
      assert result.severity == :high
    end

    test "detects threat" do
      result = BehaviorDetector.detect_aggression("Vou te tirar da sala se não parar!")

      assert result.detected == true
      assert result.severity == :critical
    end

    test "detects competence insult" do
      result = BehaviorDetector.detect_aggression("Você é completamente incapaz!")

      assert result.detected == true
      assert result.severity == :critical
    end

    test "returns no detection for constructive feedback" do
      result =
        BehaviorDetector.detect_aggression(
          "Você pode melhorar nesse ponto, vamos tentar de novo."
        )

      assert result.detected == false
    end
  end

  describe "analyze/1" do
    test "returns complete behavior report" do
      text = """
      Só isso? Você tem essa mania de errar.
      Ivã dormiu de novo, acorda ele.
      Perfume, você me cheirou assim na frente de todo mundo?
      """

      result = BehaviorDetector.analyze(text)

      assert result.sarcasm.detected == true
      assert result.disengagement.detected == true
      assert result.public_shame.detected == true
      assert result.safety_score < 50
      assert result.lei_13185_risk == :critical
      assert String.contains?(result.summary, "sarcasm")
    end

    test "returns high safety score for clean transcription" do
      text = """
      Bom dia, turma! Vamos começar a aula de hoje.
      Quem pode me dizer o que aprendemos ontem?
      Muito bem, João! Excelente resposta.
      Alguém mais quer contribuir?
      """

      result = BehaviorDetector.analyze(text)

      assert result.safety_score >= 80
      assert result.lei_13185_risk in [:none, :low]
      assert result.summary == "No problematic behaviors detected"
    end

    test "calculates correct safety score with multiple issues" do
      text = "Só sim? Claro, né. Você tem essa mania. Cadê o Pedro?"
      result = BehaviorDetector.analyze(text)

      # Multiple issues should reduce safety score
      assert result.safety_score < 70
    end
  end

  describe "calculate_safety_score/1" do
    test "starts at 100 for no detections" do
      detections = %{
        sarcasm: %{detected: false, severity: :none, score_impact: 0},
        disengagement: %{detected: false, severity: :none, score_impact: 0},
        public_shame: %{detected: false, severity: :none, score_impact: 0}
      }

      assert BehaviorDetector.calculate_safety_score(detections) == 100
    end

    test "reduces score based on impacts" do
      detections = %{
        sarcasm: %{detected: true, severity: :critical, score_impact: -25},
        disengagement: %{detected: true, severity: :high, score_impact: -12}
      }

      score = BehaviorDetector.calculate_safety_score(detections)
      assert score == 63
    end

    test "never goes below 0" do
      detections = %{
        a: %{score_impact: -50},
        b: %{score_impact: -50},
        c: %{score_impact: -50}
      }

      assert BehaviorDetector.calculate_safety_score(detections) == 0
    end
  end

  describe "calculate_lei_13185_risk/1" do
    test "returns :critical for multiple critical severities" do
      detections = %{
        sarcasm: %{severity: :critical},
        public_shame: %{severity: :critical}
      }

      assert BehaviorDetector.calculate_lei_13185_risk(detections) == :critical
    end

    test "returns :critical for one critical and one high" do
      detections = %{
        sarcasm: %{severity: :critical},
        disengagement: %{severity: :high}
      }

      assert BehaviorDetector.calculate_lei_13185_risk(detections) == :critical
    end

    test "returns :high for single critical" do
      detections = %{
        sarcasm: %{severity: :critical},
        other: %{severity: :none}
      }

      assert BehaviorDetector.calculate_lei_13185_risk(detections) == :high
    end

    test "returns :high for two high severities" do
      detections = %{
        sarcasm: %{severity: :high},
        disengagement: %{severity: :high}
      }

      assert BehaviorDetector.calculate_lei_13185_risk(detections) == :high
    end

    test "returns :medium for single high" do
      detections = %{
        sarcasm: %{severity: :high},
        other: %{severity: :none}
      }

      assert BehaviorDetector.calculate_lei_13185_risk(detections) == :medium
    end

    test "returns :low for medium severity only" do
      detections = %{
        sarcasm: %{severity: :medium},
        other: %{severity: :none}
      }

      assert BehaviorDetector.calculate_lei_13185_risk(detections) == :low
    end

    test "returns :none for no issues" do
      detections = %{
        sarcasm: %{severity: :none},
        other: %{severity: :none}
      }

      assert BehaviorDetector.calculate_lei_13185_risk(detections) == :none
    end
  end

  describe "real-world examples" do
    test "analyzes typical problematic class" do
      # Based on actual transcription patterns from the improvement plan
      text = """
      Professora: Abre na página 33. Augusto, lê o primeiro parágrafo.
      Augusto: (lendo) Cyberbullying é quando...
      Professora: Só sim? Você tem essa mania de ler assim?
      Maíra: Eu não quero mais ler.
      Professora: Cadê o Ivão? Ele dormiu de novo?
      Ellen: Ele tá dormindo lá no fundo.
      Professora: (suspiro) Acorda ele, Sônia.
      Sônia: Perfume, você me cheirou assim? (risos da turma)
      """

      result = BehaviorDetector.analyze(text)

      # Should detect multiple issues
      assert result.sarcasm.detected == true
      assert result.disengagement.detected == true
      assert result.public_shame.detected == true

      # Safety should be very low
      assert result.safety_score < 40

      # High legal risk
      assert result.lei_13185_risk == :critical

      # Summary should list detected behaviors
      assert String.contains?(result.summary, "sarcasm")
      assert String.contains?(result.summary, "critical")
    end

    test "analyzes model classroom interaction" do
      text = """
      Professora: Bom dia, turma! Como vocês estão hoje?
      Alunos: Bom dia, professora!
      Professora: Hoje vamos falar sobre um tema muito importante: cyberbullying.
      Alguém sabe o que é cyberbullying?
      João: É quando fazem bullying pela internet?
      Professora: Excelente, João! Isso mesmo. E vocês sabiam que existe uma lei
      que protege vocês? A Lei 13.185 de 2015 define nove tipos de bullying.
      Vamos conhecer cada um deles?
      Maria: Professora, o que a gente faz se ver alguém sofrendo cyberbullying?
      Professora: Ótima pergunta, Maria! Vou mostrar três passos importantes...
      """

      result = BehaviorDetector.analyze(text)

      # Should not detect problematic behaviors
      assert result.sarcasm.detected == false
      assert result.disengagement.detected == false
      assert result.public_shame.detected == false

      # High safety score
      assert result.safety_score >= 90

      # No legal risk
      assert result.lei_13185_risk == :none
    end
  end
end
