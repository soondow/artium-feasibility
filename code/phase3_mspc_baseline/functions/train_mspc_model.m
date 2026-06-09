function model = train_mspc_model(XTrain, explainedVarianceTarget)
% 함수 설명:
%   고품질 정상 윈도우 특징으로 PCA 기반 MSPC 기준 모델을 학습합니다.
%
% 입력:
%   XTrain (수치형 행렬, 비어 있을 수 없음: 정상 기준 학습에 사용할 HRV 특징 행렬입니다.)
%   explainedVarianceTarget (수치형 스칼라, 비어 있을 수 있음: 유지할 누적 설명분산 목표 비율입니다.)
%
% 출력:
%   model (구조체: 평균, 표준편차, PCA 계수, 고유값, 선택 주성분 수, T2/Q 기준값을 담습니다.)
%
% 예외:
%   완전한 학습 행이 5개 미만이면 error를 발생시키며, 행렬 연산 조건이 맞지 않으면 예외가 전파됩니다.
%
% 처리 절차:
%   1. 완전한 학습 행만 남기고 특징을 표준화합니다.
%   2. SVD로 PCA 축과 고유값을 계산합니다.
%   3. 목표 설명분산을 만족하는 최소 주성분 수를 선택합니다.
%   4. 학습 데이터의 T2와 Q 잔차 분포에서 95% 기준값을 저장합니다.

    if nargin < 2 || isempty(explainedVarianceTarget)
        explainedVarianceTarget = 0.90;
    end

    XTrain = XTrain(all(isfinite(XTrain), 2), :);
    if size(XTrain, 1) < 5
        error('MSPC training requires at least five complete high-quality normal windows.');
    end

    mu = mean(XTrain, 1, 'omitnan');
    sigma = std(XTrain, 0, 1, 'omitnan');
    sigma(sigma == 0 | isnan(sigma)) = 1;

    Z = (XTrain - mu) ./ sigma;
    [~, S, coeff] = svd(Z, 'econ');
    latent = diag(S) .^ 2 ./ max(size(Z, 1) - 1, 1);

    explained = cumsum(latent) ./ max(sum(latent), eps);
    numPC = find(explained >= explainedVarianceTarget, 1, 'first');
    if isempty(numPC)
        numPC = numel(latent);
    end

    P = coeff(:, 1:numPC);
    scores = Z * P;
    T2Train = sum((scores .^ 2) ./ latent(1:numPC)', 2);

    ZHat = scores * P';
    E = Z - ZHat;
    QTrain = sum(E .^ 2, 2);

    model = struct();
    model.mu = mu;
    model.sigma = sigma;
    model.coeff = coeff;
    model.latent = latent;
    model.numPC = numPC;
    model.T2_limit = percentile95(T2Train);
    model.Q_limit = percentile95(QTrain);
    model.explained_variance_target = explainedVarianceTarget;
end

function y = percentile95(x)
% 함수 설명:
%   유한한 값의 경험적 95번째 백분위수를 계산하고 양수 기준값을 보장합니다.
%
% 입력:
%   x (수치형 값 또는 배열, 비어 있을 수 없음: 계산 대상 값입니다.)
%
% 출력:
%   y (수치형 값 또는 배열: 안전 비율, 제한값, sigmoid 결과, 또는 백분위수 결과입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    x = sort(x(isfinite(x)));
    if isempty(x)
        y = 1;
        return;
    end

    idx = max(1, ceil(0.95 * numel(x)));
    y = x(idx);
    if y <= 0 || isnan(y)
        y = eps;
    end
end
