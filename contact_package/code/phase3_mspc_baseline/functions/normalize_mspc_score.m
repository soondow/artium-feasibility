function risk = normalize_mspc_score(mspcScore)
%NORMALIZE_MSPC_SCORE MSPC 이상 점수를 제한된 위험 관측값으로 변환한다.
%
% mspcScore = 1은 경험적 95% 정상운전 한계에 해당한다.
% 제한 매핑은 MSPC를 최종 의사결정이 아닌 관측 후보로 유지한다.
% Phase 2 제어기는 여전히 품질 및 안전 게이트를 적용한다.

    risk = 0.12 + 0.58 * (1 - exp(-0.75 * mspcScore));
    risk = min(max(risk, 0), 1);
end
