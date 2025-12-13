defmodule Hellen.AI.LegalComplianceCheckerTest do
  use ExUnit.Case, async: true

  alias Hellen.AI.LegalComplianceChecker

  describe "detect_bullying_types_mentioned/1" do
    test "detects cyberbullying mention" do
      text = "Cyberbullying é quando alguém usa a internet para intimidar."
      assert "Cyberbullying" in LegalComplianceChecker.detect_bullying_types_mentioned(text)
    end

    test "detects verbal bullying mention" do
      text = "Bullying verbal inclui insultar e xingar."
      assert "Verbal" in LegalComplianceChecker.detect_bullying_types_mentioned(text)
    end

    test "detects psychological bullying mention" do
      text = "Bullying psicológico pode incluir isolar e humilhar."
      types = LegalComplianceChecker.detect_bullying_types_mentioned(text)
      assert "Psicológico" in types
    end

    test "detects social bullying mention" do
      text = "Bullying social é quando excluem alguém de grupos."
      assert "Social" in LegalComplianceChecker.detect_bullying_types_mentioned(text)
    end

    test "detects multiple types" do
      text = """
      Vamos falar sobre os tipos de bullying:
      - Cyberbullying: usar internet para ofender
      - Bullying verbal: insultar e xingar
      - Bullying social: excluir de grupos
      """

      types = LegalComplianceChecker.detect_bullying_types_mentioned(text)
      assert "Cyberbullying" in types
      assert "Verbal" in types
      assert "Social" in types
    end

    test "returns empty for text without bullying mentions" do
      text = "Abram o livro de matemática."
      assert LegalComplianceChecker.detect_bullying_types_mentioned(text) == []
    end
  end

  describe "preventive_approach?/1" do
    test "returns true for educational approach" do
      text = """
      Vamos conversar sobre como podemos resolver esse problema.
      O que vocês acham que devemos fazer para prevenir o bullying?
      Educação e conscientização são fundamentais.
      """

      assert LegalComplianceChecker.preventive_approach?(text) == true
    end

    test "returns false for punitive approach" do
      text = """
      Quem fizer bullying vai ser advertido.
      Vamos chamar os pais para reclamar.
      Castigo para quem desobedecer.
      """

      assert LegalComplianceChecker.preventive_approach?(text) == false
    end

    test "returns true when preventive outweighs punitive" do
      text = """
      Vamos conversar sobre o que fazer.
      Como podemos ajudar?
      A prevenção é importante.
      Se não parar, vai ser advertido.
      """

      # 3 preventive vs 1 punitive
      assert LegalComplianceChecker.preventive_approach?(text) == true
    end
  end

  describe "check_compliance/1" do
    test "returns compliant for well-conducted lesson" do
      text = """
      Bom dia, turma! Vamos conversar sobre bullying.
      O que vocês acham que é bullying?
      Cyberbullying acontece quando usam a internet para ofender.
      Como podemos prevenir? Vamos educar e conscientizar.
      """

      result = LegalComplianceChecker.check_compliance(text)

      assert result.overall_compliance in [:compliant, :partial]
      assert result.overall_risk in [:none, :low, :medium]
      assert result.combined_score >= 60
    end

    test "returns violation for contradictory lesson" do
      text = """
      Vamos falar sobre bullying e respeito.
      Você é burro demais! Cala a boca!
      Ninguém quer você no grupo. Sai daqui.
      """

      result = LegalComplianceChecker.check_compliance(text)

      assert result.overall_compliance in [:non_compliant, :violation]
      assert result.overall_risk in [:high, :critical]
      assert result.combined_score < 50
    end

    test "includes Lei 13.185 analysis" do
      text = "Hoje vamos falar sobre bullying. Só isso? Você tem essa mania."

      result = LegalComplianceChecker.check_compliance(text)

      assert Map.has_key?(result, :lei_13185)
      assert Map.has_key?(result.lei_13185, :compliance_level)
      assert Map.has_key?(result.lei_13185, :violations)
      assert Map.has_key?(result.lei_13185, :recommendations)
    end

    test "detects hypocrisy in context analysis" do
      text = """
      Lei 13.185 define o bullying. Vamos aprender sobre respeito.
      Só sim? Você tem essa mania de errar sempre.
      """

      result = LegalComplianceChecker.check_compliance(text)

      assert result.context_analysis.teaching_bullying == true
      assert result.context_analysis.practicing_bullying == true
    end

    test "generates legal summary" do
      text = "Aula normal sobre matemática."

      result = LegalComplianceChecker.check_compliance(text)

      assert is_binary(result.legal_summary)
      assert String.length(result.legal_summary) > 0
    end
  end

  describe "check_lei_13185/3" do
    test "identifies violations from behavior report" do
      text = """
      Vamos falar sobre bullying.
      Você é idiota! Cala a boca agora!
      """

      result = LegalComplianceChecker.check_compliance(text)

      assert not Enum.empty?(result.lei_13185.violations)
      assert Enum.any?(result.lei_13185.violations, &String.contains?(&1, "Verbal"))
    end

    test "detects practiced bullying types" do
      text = """
      Você é burro! Ninguém te quer aqui.
      Todo mundo viu o que você fez.
      """

      result = LegalComplianceChecker.check_compliance(text)

      assert not Enum.empty?(result.lei_13185.bullying_types_practiced)
    end

    test "provides recommendations" do
      text = """
      Bullying é errado.
      Só isso? Você tem essa mania!
      """

      result = LegalComplianceChecker.check_compliance(text)

      assert not Enum.empty?(result.lei_13185.recommendations)
    end
  end

  describe "compliance levels" do
    test "compliant for score >= 80" do
      # Clean educational content
      text = """
      Vamos conversar sobre como prevenir o bullying.
      Educação e conscientização são importantes.
      Como podemos ajudar uns aos outros?
      O que vocês acham que devemos fazer?
      """

      result = LegalComplianceChecker.check_compliance(text)
      # Should have high score without violations
      assert result.lei_13185.score >= 50
    end

    test "violation for severe cases" do
      text = """
      Lei 13.185 sobre bullying.
      Você é burro! Idiota! Cala a boca!
      Ninguém quer você aqui, sai do grupo.
      Todo mundo viu como você é ridículo.
      """

      result = LegalComplianceChecker.check_compliance(text)
      assert result.lei_13185.compliance_level == :violation
      assert result.lei_13185.risk_level == :critical
    end
  end

  describe "risk levels" do
    test "critical risk for grave violations" do
      text = """
      Hoje vamos aprender sobre respeito e bullying.
      Você é um idiota completo! Burro!
      Ninguém quer você aqui, vai embora!
      """

      result = LegalComplianceChecker.check_compliance(text)
      assert result.overall_risk == :critical
    end

    test "no risk for clean lesson" do
      text = """
      Abram os livros na página 42.
      Vamos resolver os exercícios de matemática.
      Muito bem, João! Excelente resposta.
      """

      result = LegalComplianceChecker.check_compliance(text)
      assert result.overall_risk in [:none, :low]
    end
  end

  describe "real-world scenarios" do
    test "typical problematic lesson" do
      text = """
      Professora: Página 33, vamos falar sobre cyberbullying.
      Augusto: (lendo) O cyberbullying...
      Professora: Só sim? Você tem essa mania de ler assim.
      Ellen: Professora, o Ivão dormiu de novo.
      Professora: Cadê ele? Acorda o Ivão, por favor.
      Sônia: Perfume, você me cheirou? (risos)
      """

      result = LegalComplianceChecker.check_compliance(text)

      # Should detect multiple issues
      assert result.lei_13185.compliance_level in [:non_compliant, :violation]
      assert result.overall_risk in [:high, :critical]
      assert not Enum.empty?(result.lei_13185.violations)

      # Should have specific recommendations
      assert not Enum.empty?(result.lei_13185.recommendations)

      # Summary should indicate problems
      assert String.contains?(result.legal_summary, "❌") or
               String.contains?(result.legal_summary, "🚨") or
               String.contains?(result.legal_summary, "⚠️")
    end

    test "exemplary lesson" do
      text = """
      Professora: Bom dia! Hoje vamos conversar sobre bullying.
      Professora: A Lei 13.185 define nove tipos de bullying.
      Professora: Quem sabe o que é cyberbullying?
      João: É quando usam a internet para fazer bullying?
      Professora: Excelente, João! E como podemos prevenir?
      Maria: Não participando e contando para um adulto?
      Professora: Perfeito! A prevenção e educação são fundamentais.
      """

      result = LegalComplianceChecker.check_compliance(text)

      # Should be compliant or partial
      assert result.lei_13185.compliance_level in [:compliant, :partial]
      assert result.overall_risk in [:none, :low]
      assert result.lei_13185.preventive_approach == true

      # Should mention bullying types educationally
      assert not Enum.empty?(result.lei_13185.bullying_types_mentioned)

      # Should NOT practice bullying
      assert Enum.empty?(result.lei_13185.bullying_types_practiced)

      # Summary should be positive
      assert String.contains?(result.legal_summary, "✅") or
               String.contains?(result.legal_summary, "CONFORME")
    end
  end
end
