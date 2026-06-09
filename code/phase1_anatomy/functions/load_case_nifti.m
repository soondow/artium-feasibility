function [img, lab, infoImg, infoLab] = load_case_nifti(imgPath, labPath)
% 함수 설명:
%   한 케이스의 MRI 영상과 라벨 NIfTI 파일을 메타데이터와 함께 읽습니다.
%
% 입력:
%   imgPath (문자열, 비어 있을 수 없음: MRI NIfTI 파일 경로입니다.)
%   labPath (문자열, 비어 있을 수 없음: 라벨 NIfTI 파일 경로입니다.)
%
% 출력:
%   img (수치형 배열: MRI 영상 볼륨입니다.)
%   lab (수치형 배열: 라벨 볼륨입니다.)
%   infoImg (구조체: MRI NIfTI 메타데이터입니다.)
%   infoLab (구조체: 라벨 NIfTI 메타데이터입니다.)
%
% 예외:
%   파일이 없거나 형식이 잘못되면 niftiinfo 또는 niftiread 예외가 발생합니다.
    infoImg = niftiinfo(imgPath);
    infoLab = niftiinfo(labPath);

    img = double(niftiread(infoImg));
    lab = double(niftiread(infoLab));
end
