function S = score_mspc_model(X, model)
% 함수 설명:
%   학습된 MSPC 모델로 HRV 특징 윈도우의 T2, Q, 정규화 이상 점수를 계산합니다.
%
% 입력:
%   X (수치형 행렬, 비어 있을 수 없음: 점수화할 HRV 특징 행렬입니다.)
%   model (구조체, 비어 있을 수 없음: 학습된 MSPC 기준 모델입니다.)
%
% 출력:
%   S (구조체 또는 테이블: 함수 목적에 따른 합성 신호, MSPC 점수, 또는 요약 결과를 담습니다.)
%
% 예외:
%   입력 특징 열 수가 모델 차원과 맞지 않으면 행렬 연산 오류가 발생합니다.
%
% 처리 절차:
%   1. 입력 특징을 학습 평균과 표준편차로 표준화합니다.
%   2. 완전한 행만 PCA 부분공간에 투영합니다.
%   3. 점수 공간 편차 T2와 잔차 공간 편차 Q를 계산합니다.
%   4. 각 기준 한계로 정규화한 뒤 더 큰 값을 MSPC 관측 점수로 사용합니다.

    Z = (X - model.mu) ./ model.sigma;
    completeRows = all(isfinite(Z), 2);

    T2 = nan(size(X, 1), 1);
    Q = nan(size(X, 1), 1);
    T2Norm = nan(size(X, 1), 1);
    QNorm = nan(size(X, 1), 1);
    mspcScore = nan(size(X, 1), 1);

    P = model.coeff(:, 1:model.numPC);
    latent = model.latent(1:model.numPC);

    scores = Z(completeRows, :) * P;
    T2(completeRows) = sum((scores .^ 2) ./ latent', 2);

    ZHat = scores * P';
    E = Z(completeRows, :) - ZHat;
    Q(completeRows) = sum(E .^ 2, 2);

    T2Norm(completeRows) = T2(completeRows) ./ max(model.T2_limit, eps);
    QNorm(completeRows) = Q(completeRows) ./ max(model.Q_limit, eps);
    mspcScore(completeRows) = max(T2Norm(completeRows), QNorm(completeRows));
    mspcScore = min(max(mspcScore, 0), 5);

    S = table(T2, Q, T2Norm, QNorm, mspcScore, completeRows, ...
        'VariableNames', {'T2', 'Q', 'T2_norm', 'Q_norm', 'mspc_score', 'complete_row'});
end
