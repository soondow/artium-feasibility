function F = extract_hrv_features(rriMs, validMask)
% 함수 설명:
%   유효 RRI 박동에서 시간 영역 HRV 특징과 불규칙성 위험 프록시를 계산합니다.
%
% 입력:
%   rriMs (수치형 벡터, 비어 있을 수 없음: 밀리초 단위 RRI 값입니다. NaN은 결측으로 처리합니다.)
%   validMask (논리형 벡터, 비어 있을 수 있음: 특징 계산에 사용할 유효 샘플 마스크입니다.)
%
% 출력:
%   F (구조체: 박동 수, HRV 특징, 불규칙성 점수, 상태 라벨을 담습니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.

    if nargin < 2 || isempty(validMask)
        validMask = ~isnan(rriMs(:));
    end

    rriMs = rriMs(:);
    validMask = validMask(:) & ~isnan(rriMs);
    x = rriMs(validMask);

    F = emptyFeatureStruct();
    F.n_beats = numel(x);

    if numel(x) < 20
        F.status = "insufficient_beats";
        return;
    end

    dx = diff(x);
    meanNN = mean(x);
    sdnn = std(x, 0);
    rmssd = sqrt(mean(dx .^ 2));
    pnn50 = mean(abs(dx) > 50);
    cvRri = sdnn / meanNN;
    sd1 = rmssd / sqrt(2);
    sd2 = sqrt(max(2 * sdnn ^ 2 - 0.5 * rmssd ^ 2, 0));

    F.meanNN_ms = meanNN;
    F.SDNN_ms = sdnn;
    F.RMSSD_ms = rmssd;
    F.pNN50 = pnn50;
    F.CV_RRI = cvRri;
    F.SD1_ms = sd1;
    F.SD2_ms = sd2;
    F.irregularity_index = estimate_irregularity(F);
    F.status = "ok";
end

function F = emptyFeatureStruct()
% 함수 설명:
%   HRV 특징 계산 전 또는 샘플 부족 상황에서 사용할 기본 특징 구조체를 생성합니다.
%
% 입력:
%   없음.
%
% 출력:
%   F (구조체: 박동 수, HRV 특징, 불규칙성 점수, 상태 라벨을 담습니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    F = struct();
    F.n_beats = 0;
    F.meanNN_ms = NaN;
    F.SDNN_ms = NaN;
    F.RMSSD_ms = NaN;
    F.pNN50 = NaN;
    F.CV_RRI = NaN;
    F.SD1_ms = NaN;
    F.SD2_ms = NaN;
    F.irregularity_index = NaN;
    F.status = "empty";
end

function score = estimate_irregularity(F)
% 함수 설명:
%   여러 HRV 특징을 결합해 0 이상 1 이하의 불규칙성 위험 프록시를 계산합니다.
%
% 입력:
%   F (구조체, 비어 있을 수 없음: HRV 특징 필드를 포함한 구조체입니다.)
%
% 출력:
%   score (수치형 스칼라: 정규화된 불규칙성 점수입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    rmssdTerm = sigmoid01((F.RMSSD_ms - 55) / 18);
    cvTerm = sigmoid01((F.CV_RRI - 0.075) / 0.025);
    pnnTerm = sigmoid01((F.pNN50 - 0.25) / 0.10);
    sdnnTerm = sigmoid01((F.SDNN_ms - 70) / 22);

    score = 0.35 * rmssdTerm + 0.25 * cvTerm + 0.25 * pnnTerm + 0.15 * sdnnTerm;
    score = min(max(score, 0), 1);
end

function y = sigmoid01(x)
% 함수 설명:
%   입력값을 sigmoid 함수로 0 이상 1 이하 범위에 매핑합니다.
%
% 입력:
%   x (수치형 값 또는 배열, 비어 있을 수 없음: 계산 대상 값입니다.)
%
% 출력:
%   y (수치형 값 또는 배열: 안전 비율, 제한값, sigmoid 결과, 또는 백분위수 결과입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    y = 1 ./ (1 + exp(-x));
end
