function volume_ml = compute_la_volume_nrrd(labVol, labInfo)
% 함수 설명:
%   NRRD 라벨 볼륨의 좌심방 전경 복셀 수와 복셀 간격으로 부피를 계산합니다.
%
% 입력:
%   labVol (수치형 배열, 비어 있을 수 없음: 좌심방 라벨 볼륨입니다. 0보다 큰 값은 전경으로 처리합니다.)
%   labInfo (구조체, 비어 있을 수 없음: PixelDimensions 필드를 포함하는 라벨 메타데이터입니다.)
%
% 출력:
%   volume_ml (수치형 스칼라: 전경 복셀 수와 복셀 물리 부피로 계산한 좌심방 부피입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
%
% 처리 절차:
%   1. 라벨 볼륨을 이진 전경 마스크로 변환합니다.
%   2. 전경 복셀 수와 복셀당 물리 부피를 곱합니다.
%   3. 세제곱밀리미터 값을 1000으로 나누어 mL로 변환합니다.
    labMask = labVol > 0;
    voxelCount = nnz(labMask);

    spacing = labInfo.PixelDimensions;
    voxelVolMm3 = spacing(1) * spacing(2) * spacing(3);

    volume_ml = (voxelCount * voxelVolMm3) / 1000;
end
