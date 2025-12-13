defmodule Hellen.AI.ContextDetectorTest do
  use ExUnit.Case, async: true

  alias Hellen.AI.ContextDetector

  describe "detect_topics/1" do
    test "detects bullying topic" do
      text = "Hoje vamos falar sobre bullying e como podemos preveni-lo."
      assert :bullying in ContextDetector.detect_topics(text)
    end

    test "detects cyberbullying topic" do
      text = "O cyberbullying é quando alguém usa a internet para intimidar outras pessoas."
      assert :cyberbullying in ContextDetector.detect_topics(text)
    end

    test "detects Lei 13.185 reference" do
      text = "A Lei 13.185 de 2015 define nove tipos de bullying."
      assert :bullying in ContextDetector.detect_topics(text)
    end

    test "detects respect topic" do
      text = "Respeito e empatia são fundamentais para uma boa convivência."
      assert :respect in ContextDetector.detect_topics(text)
    end

    test "detects inclusion topic" do
      text = "Inclusão e diversidade devem ser valorizadas em nossa escola."
      assert :inclusion in ContextDetector.detect_topics(text)
    end

    test "detects citizenship topic" do
      text = "Vamos aprender sobre cidadania e nossos direitos e deveres."
      assert :citizenship in ContextDetector.detect_topics(text)
    end

    test "detects multiple topics" do
      text = """
      Hoje vamos falar sobre bullying, respeito e cidadania digital.
      É importante exercer empatia com os colegas.
      """

      topics = ContextDetector.detect_topics(text)

      assert :bullying in topics
      assert :respect in topics
      assert :citizenship in topics
    end

    test "returns empty for unrelated topics" do
      text = "Abram o livro de matemática na página 42."
      assert ContextDetector.detect_topics(text) == []
    end
  end

  describe "topic_detected?/2" do
    test "returns true when topic is present" do
      assert ContextDetector.topic_detected?("Vamos falar sobre bullying", :bullying)
    end

    test "returns false when topic is absent" do
      refute ContextDetector.topic_detected?("Abram os livros", :bullying)
    end
  end

  describe "contradiction_multiplier/2" do
    test "returns 2.5 for bullying + sarcasm" do
      assert ContextDetector.contradiction_multiplier(:bullying, :sarcasm) == 2.5
    end

    test "returns 2.5 for bullying + public_shame" do
      assert ContextDetector.contradiction_multiplier(:bullying, :public_shame) == 2.5
    end

    test "returns 2.0 for respect + aggression" do
      assert ContextDetector.contradiction_multiplier(:respect, :aggression) == 2.0
    end

    test "returns 2.0 for inclusion + exclusion" do
      assert ContextDetector.contradiction_multiplier(:inclusion, :exclusion) == 2.0
    end

    test "returns 1.0 for non-contradicting pairs" do
      assert ContextDetector.contradiction_multiplier(:other, :sarcasm) == 1.0
    end
  end

  describe "analyze/1" do
    test "detects hypocrisy when teaching bullying but using sarcasm" do
      text = """
      Hoje vamos falar sobre bullying. É muito importante respeitar os colegas.
      Só sim? Você tem essa mania de fazer assim.
      """

      result = ContextDetector.analyze(text)

      assert result.teaching_about_bullying == true
      assert result.practicing_bullying == true
      assert not Enum.empty?(result.contradictions)
      assert result.hypocrisy_score < 70
    end

    test "detects critical contradiction for bullying lesson with sarcasm" do
      text = """
      Vamos aprender sobre a Lei 13.185, a lei do bullying.
      Só isso? Você tem essa mania de errar!
      """

      result = ContextDetector.analyze(text)

      critical_contradictions =
        Enum.filter(result.contradictions, &(&1.severity == :critical))

      assert not Enum.empty?(critical_contradictions)
    end

    test "returns clean report for well-conducted lesson" do
      text = """
      Bom dia, turma! Hoje vamos conversar sobre bullying.
      O que vocês acham que é bullying?
      Muito bem, João! Isso mesmo.
      Alguém sabe como podemos ajudar quem sofre bullying?
      """

      result = ContextDetector.analyze(text)

      assert result.teaching_about_bullying == true
      assert result.practicing_bullying == false
      assert Enum.empty?(result.contradictions)
      assert result.hypocrisy_score == 100
    end

    test "detects contradiction in inclusion lesson with exclusion" do
      text = """
      Inclusão é muito importante. Todos devem participar.
      Você não pode participar dessa atividade. Fica aí sozinho.
      """

      result = ContextDetector.analyze(text)

      assert :inclusion in result.detected_topics
      contradiction_topics = Enum.map(result.contradictions, & &1.topic)
      assert :inclusion in contradiction_topics
    end

    test "calculates appropriate hypocrisy score" do
      # No contradictions
      clean_text = "Abram os livros na página 33."
      clean_result = ContextDetector.analyze(clean_text)
      assert clean_result.hypocrisy_score == 100

      # With contradictions
      bad_text = """
      Vamos falar sobre respeito e empatia.
      Você é burro demais! Cala a boca!
      """

      bad_result = ContextDetector.analyze(bad_text)
      assert bad_result.hypocrisy_score < 50
    end
  end

  describe "real-world scenarios" do
    test "typical problematic bullying lesson" do
      text = """
      Professora: Abram na página 33, vamos falar sobre cyberbullying.
      Professora: Augusto, lê o primeiro parágrafo.
      Augusto: (lendo) Cyberbullying é quando...
      Professora: Só sim? Você tem essa mania de ler assim.
      Maíra: Eu não quero mais ler.
      Professora: Cadê o Ivão? Dormiu de novo?
      Sônia: Perfume, você me cheirou assim? (risos)
      """

      result = ContextDetector.analyze(text)

      # Should detect cyberbullying topic
      assert :cyberbullying in result.detected_topics or :bullying in result.detected_topics

      # Should detect practicing bullying
      assert result.practicing_bullying == true

      # Should have contradictions
      assert not Enum.empty?(result.contradictions)

      # Hypocrisy score should be low
      assert result.hypocrisy_score < 50

      # Recommendation should be urgent
      assert String.contains?(result.recommendation, "ALERTA") or
               String.contains?(result.recommendation, "contradição")
    end

    test "model bullying lesson" do
      text = """
      Professora: Bom dia, turma! Hoje vamos conversar sobre um tema muito importante.
      Professora: Quem já ouviu falar em bullying?
      João: É quando alguém fica zoando outra pessoa, né?
      Professora: Isso mesmo, João! E vocês sabiam que existe uma lei que nos protege?
      Professora: A Lei 13.185 define nove tipos de bullying. Vamos conhecer cada um?
      Maria: Professora, o que a gente faz se ver alguém sofrendo bullying?
      Professora: Ótima pergunta, Maria! Primeiro, nunca ria ou ignore.
      Professora: Segundo, conte para um adulto de confiança. Terceiro, apoie a vítima.
      """

      result = ContextDetector.analyze(text)

      # Should detect bullying topic
      assert result.teaching_about_bullying == true

      # Should NOT detect practicing bullying
      assert result.practicing_bullying == false

      # Should have no contradictions
      assert Enum.empty?(result.contradictions)

      # Perfect hypocrisy score
      assert result.hypocrisy_score == 100

      # Positive recommendation
      assert String.contains?(result.recommendation, "Nenhuma contradição") or
               String.contains?(result.recommendation, "alinhada")
    end
  end
end
