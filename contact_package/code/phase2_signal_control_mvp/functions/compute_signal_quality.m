function Q = compute_signal_quality(rriMs, varargin)
% 함수 설명:
%   RRI 윈도우의 커버리지, 범위 위반, 이상치, 연속성을 이용해 신호 품질 지수를 계산합니다.
%
% 입력:
%   rriMs (수치형 벡터, 비어 있을 수 없음: 밀리초 단위 RRI 값입니다. NaN은 결측으로 처리합니다.)
%   varargin (가변 인자 목록, 비어 있을 수 있음: 이름-값 형식의 선택 파라미터입니다.)
%
% 출력:
%   Q (구조체: 종합 품질 점수, 세부 품질 점수, 결측 및 이상치 마스크를 담습니다.)
%
% 예외:
%   inputParser 검증 조건을 만족하지 못하면 인자 검증 예외가 발생합니다.
%
% 처리 절차:
%   1. 결측률과 생리적 범위 위반 비율을 계산합니다.
%   2. 충분한 정상 범위 값이 있으면 중앙값과 MAD로 강건 이상치를 찾습니다.
%   3. 유효 RRI의 급격한 변화 비율로 연속성 점수를 계산합니다.
%   4. 커버리지, 범위 점수, 인공물 점수, 연속성 점수를 가중합해 최종 품질 점수를 만듭니다.

    p = inputParser;
    addRequired(p, 'rriMs', @(x) isnumeric(x) && isvector(x));
    addParameter(p, 'PhysRangeMs', [300 2000], @(x) isnumeric(x) && numel(x) == 2);
    addParameter(p, 'RobustZLimit', 8.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'JumpFractionLimit', 0.70, @(x) isnumeric(x) && isscalar(x) && x > 0);
    parse(p, rriMs, varargin{:});

    rriMs = rriMs(:);
    n = numel(rriMs);

    missingMask = isnan(rriMs);
    coverage = 1 - mean(missingMask);

    physRange = p.Results.PhysRangeMs;
    rangeValidMask = ~missingMask & rriMs >= physRange(1) & rriMs <= physRange(2);
    rangeViolationRatio = mean(~missingMask & ~rangeValidMask);
    rangeScore = 1 - safeRatio(nnz(~missingMask & ~rangeValidMask), nnz(~missingMask));

    cleanRangeValues = rriMs(rangeValidMask);
    robustOutlierMask = false(n, 1);
    jumpOutlierMask = false(n, 1);

    if numel(cleanRangeValues) >= 8
        medRri = median(cleanRangeValues);
        madRri = median(abs(cleanRangeValues - medRri));
        robustSigma = max(1.4826 * madRri, 1);

        robustZ = abs(rriMs - medRri) ./ robustSigma;
        robustOutlierMask = rangeValidMask & robustZ > p.Results.RobustZLimit;

        validIdx = find(rangeValidMask);
        validRri = rriMs(validIdx);
        jumpMaskValid = [false; abs(diff(validRri)) > p.Results.JumpFractionLimit * medRri];
        jumpOutlierMask(validIdx) = jumpMaskValid;
    end

    artifactMask = robustOutlierMask | jumpOutlierMask;
    artifactRatio = mean(artifactMask);
    validMask = rangeValidMask & ~artifactMask;

    if numel(cleanRangeValues) >= 3
        medRri = median(cleanRangeValues);
        jumpRatio = mean(abs(diff(cleanRangeValues)) > p.Results.JumpFractionLimit * medRri);
    else
        jumpRatio = 1;
    end
    continuityScore = 1 - min(1, 2.5 * jumpRatio);
    artifactScore = 1 - min(1, 4.0 * artifactRatio);

    q = 0.45 * coverage + 0.25 * rangeScore + 0.25 * artifactScore + 0.05 * continuityScore;
    q = clip01(q);

    Q = struct();
    Q.q = q;
    Q.coverage = clip01(coverage);
    Q.range_score = clip01(rangeScore);
    Q.artifact_score = clip01(artifactScore);
    Q.continuity_score = clip01(continuityScore);
    Q.missing_ratio = safeRatio(nnz(missingMask), n);
    Q.range_violation_ratio = rangeViolationRatio;
    Q.artifact_ratio = artifactRatio;
    Q.jump_ratio = jumpRatio;
    Q.missing_mask = missingMask;
    Q.range_valid_mask = rangeValidMask;
    Q.artifact_mask = artifactMask;
    Q.valid_mask = validMask;
end

function y = safeRatio(num, den)
% 함수 설명:
%   분모가 0 이하일 때 0을 반환하는 안전한 비율을 계산합니다.
%
% 입력:
%   num (수치형 값, 비어 있을 수 없음: 비율 계산의 분자입니다.)
%   den (수치형 값, 비어 있을 수 없음: 비율 계산의 분모입니다.)
%
% 출력:
%   y (수치형 값 또는 배열: 안전 비율, 제한값, sigmoid 결과, 또는 백분위수 결과입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    if den <= 0
        y = 0;
    else
        y = num ./ den;
    end
end

function y = clip01(x)
% 함수 설명:
%   입력값을 0 이상 1 이하 범위로 제한합니다.
%
% 입력:
%   x (수치형 값 또는 배열, 비어 있을 수 없음: 계산 대상 값입니다.)
%
% 출력:
%   y (수치형 값 또는 배열: 안전 비율, 제한값, sigmoid 결과, 또는 백분위수 결과입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    y = min(max(x, 0), 1);
end
