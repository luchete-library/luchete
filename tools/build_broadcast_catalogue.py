"""Prepare the seven-volume archive for review; never edit the live game catalogue."""
import datetime
import json
import re
import sys
from collections import Counter
from catalogue_public_broadcasts import DEST, ROOT, save

SUMMARIES = """
H5TE0hFUlLM|야토가 처음 인사한 데뷔 방송이에요. 이후의 주년 기록을 읽기 전에 출발점부터 만나볼 수 있어요.
sTk8yUao-gw|데뷔 다음 날, 팬네임을 정하는 시간을 담은 방송이에요. 제목에 함께 적힌 ‘안팔아요’ 코너도 같은 다시보기에 남아 있어요.
FO3Ot3LRojQ|‘야탄일’이라는 제목으로 남은 생일 방송이에요. 야토가 팬들과 생일을 맞이한 기록을 꺼내볼 수 있어요.
AQDL_yrEkWA|2024년 3월에 남겨진 3D 데뷔 방송이에요. 2026년의 3D 리뉴얼 공개와는 다른 시기의 기록이에요.
nfymca0B20I|어린이날에 ‘메스카키 버튜버 데뷔’라는 제목으로 진행한 특별 방송이에요. 야토의 첫 데뷔 방송과 구분해 보관했어요.
qC8rhRWMtw8|오리지널 곡 공개, 데뷔 방송 다시보기, 돌잡이와 축전, 시청자 이벤트와 질문 시간이 담긴 첫 주년 방송이에요.
rcYgpdoRcBE|3D 1.5와 풀 트래킹을 공개한 방송이에요. 원본 설명에는 방 소개와 춤, 카페 읽기로 이어지는 시간표도 남아 있어요.
iTt_ju65sNE|야토가 새 의상을 공개한 날의 방송이에요. 공개 당시의 모습은 아래 원본 다시보기에서 볼 수 있어요.
0GvMWMQBE1w|데뷔 500일을 축하한 방송이에요. 기념 파티와 뒤이어 진행한 포켓몬 오토체스가 한 다시보기에 담겨 있어요.
C3rXt0aBepI|2024 YATY와 새해 기념 이야기, 신년 계획을 다룬 연말 방송이에요. 한 해를 보내던 시간을 보관했어요.
hNzZzTyANRY|데뷔 2주년을 기념한 방송이에요. ‘그동안 고마웠어요’라는 원본 제목으로 두 번째 주년이 남아 있어요.
VGy1Md2LNSk|초롱과 함께한 리스텔라 신년 타로 방송이에요. 야토 시점의 긴 다시보기로 이어져요.
MPU9S-njCFk|‘외로운 유학생의 생일’이라는 제목으로 남은 2026년 생일 방송이에요. 생일 당일의 다시보기를 연결했어요.
3AIMkjjUkFk|쿠비·단밍과 함께한 만우절 방송이에요. 같은 날의 다른 멤버 기록과 함께 각자의 시점으로 볼 수 있어요.
oWPa0JYo9DY|어린이날에 ‘야리 탄신 2주년’이라는 제목으로 진행한 방송이에요. 야토 본인의 데뷔 주년과 구분해 기록했어요.
Al2ogQY4F_c|마토와 보낸 3년을 기념한 데뷔 3주년 방송이에요. 나뉘어 올라온 두 영상을 한 페이지에 묶었어요.
69gwK2UEKyI|팬미팅을 마친 뒤 이야기를 나눈 후기 방송이에요. 적힌 날짜는 팬미팅 개최일이 아니라 후기 방송 날짜예요.
16061701|2026년 11월에 진행한 야토의 3D 리뉴얼 공개예요. 당일 치지직 다시보기와 개인 채널의 공개 영상을 함께 연결했어요.
eHZJ-elBDXI|‘데뷔방송에 광고끼워넣는 신인’이라는 제목으로 남은 단밍의 데뷔 방송이에요. 달빛요정의 첫 방송 기록을 꺼내볼 수 있어요.
V2ay38gIJTM|팬네임 맞추기 이벤트와 대화를 진행한 데뷔 다음 날 방송이에요. 버리라는 이름이 등장하는 시기의 원본 기록이에요.
zThNkKqyXtM|클리프 릴레이 노래방에서 K-POP을 맡은 단밍의 방송이에요. 공식 기록집의 단체 싱크룸과는 별도의 개인 순서예요.
zYcaQ6rQBrw|2024년을 돌아보고 새해를 기다린 연말 방송이에요. 단밍의 첫해 끝자락을 다시 볼 수 있어요.
cYpAJR4XCxg|양갈래 신헤어와 커버곡을 함께 공개한 방송이에요. 공개 항목은 원본 다시보기 제목에서 확인했어요.
m2bWetJBqfQ|만우절에 ‘흑단밍 데뷔’라는 이름으로 진행한 특별 방송이에요. 2024년의 실제 첫 데뷔와는 별개의 기록이에요.
-n4kFm5wkYs|첫 생일 방송에서 커버곡과 굿즈를 공개한 기록이에요. 다른 날에 생일 방송을 다시 본 영상과 구분했어요.
p0y1Kr795lg|1주년 예열에서는 크로마 공개와 카카오 테마 배포를, 후열에서는 데뷔 방송 다시보기와 편지 읽기를 다뤘어요.
YOXTshrr7qg|크리스마스 트리를 읽은 방송이에요. 연말결산과는 별도의 크리스마스 기록으로 보관했어요.
HW5zsvjWJ6s|2025년을 돌아보는 연말정산과 술방송이에요. 한 해의 마지막 날에 남겨진 다시보기예요.
S23dgOEiSbs|서큐버스 신의상과 달라진 얼굴을 공개한 방송이에요. 공개 당시의 모습을 원본에서 확인할 수 있어요.
SDiW4m8hofw|흑단밍과 리스텔라 몸 바꾸기를 다룬 만우절 방송이에요. 2025년 흑단밍 방송과 날짜를 나누어 보관했어요.
E1GsBFeZUUw|단밍의 두 번째 생일 방송이에요. 첫 생일 기록 다음 해에 이어지는 기념일이에요.
Fej3AQ7jUzU|리스텔라가 함께한 메챠 카멜레온 합방의 단밍 시점이에요. 같은 날의 쿠비·도리·후와 시점도 각자의 책에 담았어요.
4GaKNnbCtk8|두 번째 팬미팅을 돌아본 후기 방송이에요. 날짜는 팬미팅 당일로 바꿔 적지 않고 후기 방송 기준으로 남겼어요.
3wTQ9REYoos|2주년 본방송 뒤에 이어진 단밍의 후열 방송이에요. 단밍·쿠비의 공동 기념 방송은 공식 기록집에서 볼 수 있어요.
r0oktscqoos|레이싱 신의상을 공개한 방송이에요. 이전 서큐버스 의상 공개와 따로 묶인 새 의상 기록이에요.
U6dyZAT_KyU|에테의 데뷔와 공지 방송을 함께 본 단밍의 방송이에요. 게임 속 에테의 역할과는 별개인 실제 방송 기록이에요.
gj_0ibrZmds|쿠비의 데뷔 방송이에요. 원본 설명에 오리지널 곡, 스토리, 데뷔 소개와 마무리 랩의 시간표가 남아 있어요.
bxxxJpwpUCA|클리프 릴레이 노래방에서 J-POP을 맡은 쿠비의 방송이에요. 곡별 시간표는 원본 설명에서도 확인할 수 있어요.
2p_wERFMpSU|팬네임을 정하고 맞춤법 용사를 진행한 방송이에요. 원본 설명의 시간표를 따라 팬네임 정하기 코너로 바로 갈 수 있어요.
UGE9CwaKV2c|데뷔 100일을 맞은 쿠비의 개인 방송이에요. 같은 날의 클리프 공동 합방은 공식 기록집에 따로 담았어요.
MBF1_0Eju8A|2024 HAMTY와 연말 합방, 새해 일출을 기다린 방송이에요. 한 해의 마지막 날부터 새해로 이어지는 기록이에요.
V8Mo6j1EwBM|새해를 맞아 햄님 설문조사를 진행한 방송이에요. 원본 설명에 설문조사를 시작하는 시간이 적혀 있어요.
4SApKr3uFQc|‘텐시비 강림’이라는 제목의 만우절 특별 방송이에요. 평소 방송과 다른 날의 기획으로 보관했어요.
LGecQPBS1WU|쿠비의 첫 생일 파티예요. 첫 생일을 함께한 팬들과의 방송이 다시보기로 남아 있어요.
f9vhhvz2000|햄님과 함께한 1주년 기념 파티예요. 공식 채널의 단밍·쿠비 공동 방송과는 별도의 개인 기록이에요.
CWKoXxh6ItE|할로윈에 시청자 담력시험을 진행한 방송이에요. 게임 체험과 후열 괴담 읽기도 원본 시간표에 구분되어 있어요.
wibUJfNgEgE|2025 HAMTY를 선정하고 새해 해돋이를 본 연말 방송이에요. 전년도 HAMTY와 구분해 보관했어요.
dhBUnLiUUWg|햄대리와 영혼 바꾸기를 다룬 만우절 방송이에요. 같은 날 단밍·야토 시점도 각자의 책에서 볼 수 있어요.
SrEwDsxoi9U|쿠비의 두 번째 생일 파티예요. 나뉘어 올라온 1부와 2부를 한 기록에 묶었어요.
WIhKjXGmlGA|첫 신의상과 커버곡을 공개한 방송이에요. 공개한 날의 다시보기로 연결돼요.
MuxKkSGmR4A|리스텔라 메챠 카멜레온 합방의 쿠비 시점이에요. 같은 합방을 담은 다른 멤버 영상과 구분해 표시했어요.
16173929|2026년 11월 14일에 진행한 쿠비의 3D 데뷔 방송이에요. 예고나 후기가 아닌 당일 치지직 다시보기를 연결했어요.
_Tsj7FsImlE|유네가 처음 인사한 데뷔 방송이에요. 이후 몽치와 함께 쌓아가는 방송 기록의 출발점이에요.
3_jvAGsD-Kk|데뷔를 마친 다음 날의 후기 방송이에요. 첫 방송과 그 뒤의 이야기를 차례로 꺼내볼 수 있어요.
kUwV07ysdvg|구독 오픈과 ‘노래 극복기’라는 주제로 남겨진 방송이에요. 데뷔 직후의 첫 기록들 가운데 하나예요.
vN7qV6vmQk0|100일 기념 방송 뒤에 이어진 유네의 후열 방송이에요. 세 사람의 공동 기념 방송은 공식 기록집에 있어요.
sB2ganASzNc|‘앵스텔라 합방’이라는 이름으로 남은 유네 시점의 방송이에요. 두 부분으로 올라온 다시보기를 함께 연결했어요.
VgQJv0PpABU|도리·후와와 함께한 봄바나나 합방이에요. 동기들과 함께한 방송을 유네 시점으로 볼 수 있어요.
Ly0E-lg_bRc|‘유네랑 함께하는 첫 할로윈’이라는 제목으로 남겨진 방송이에요. 데뷔 후 첫 할로윈의 기록이에요.
0m9bYVeaKj0|너구리 명탐정 지망생 도리의 데뷔 방송이에요. 돌돌이와 이어지는 방송 기록의 첫 페이지예요.
jmJr-TtiNlM|러브 샘 뒤 유네와 패들패들 패들 게릴라 합방을 진행한 기록이에요. 날짜와 두 활동이 원본 제목에 함께 남아 있어요.
1oJJWLXMTx8|메챠 카멜레온 합방과 체인드 투게더를 진행한 도리 시점의 방송이에요. 다른 멤버의 같은 날 기록과 함께 볼 수 있어요.
fSBoqOuOPuU|‘너구리로 변해버렸다’라는 제목의 첫 생일 파티예요. 생일 본방송과 뒤이은 후열 대화를 함께 묶었어요.
OvNyIVUYKNg|데뷔 100일 기념 후열로 진행한 뉴텔라 합방이에요. 공식 채널의 공동 기념 방송과 구분해 담았어요.
repvLE78oWw|단밍·야토·쿠비와 함께한 리스텔라 싱크룸 노래방이에요. 도리 시점의 다시보기를 연결했어요.
yn0mQfhQJQ8|뉴텔라가 함께한 봄바나나 합방이에요. 같은 날 유네·후와의 기록과 나란히 찾아볼 수 있어요.
WPITUa28Nps|다른 옷을 입고 진행한 할로윈 방송이에요. 전국민 결혼 대작전, 카페 탐방과 노래방이 원본 제목에 함께 적혀 있어요.
JvqjP_BAX6U|후와가 처음 인사한 데뷔 방송이에요. 텐비와 함께 쌓는 방송 기록의 첫 페이지예요.
YzWr_LxNy8Q|후와의 데뷔 방송 후기예요. 첫 방송 다음 날에 남겨진 이야기를 다시 볼 수 있어요.
FiOyC_RyKxU|‘첫 노래방’이라는 제목으로 남은 후와의 방송이에요. 데뷔 직후 처음 진행한 노래방 기록을 연결했어요.
3Mu16r5BrlI|메챠 카멜레온과 체인드 투게더 합방의 후와 시점이에요. 같은 날 다른 멤버들의 시점도 각자의 책에 담았어요.
XMgAxshaaYA|100일 방송을 마친 뒤 이어진 후와의 후열 방송이에요. 공동 기념 방송은 공식 기록집에서 볼 수 있어요.
15799452|유네·도리와 함께한 봄바나나 합방이에요. 후와 채널에 공개된 치지직 다시보기를 연결했어요.
aSiDR3Ayhuo|라면집 합방과 카페 탐방을 진행한 방송이에요. 11월에 남겨진 합방 기록을 꺼내볼 수 있어요.
BUP01PtwsiY|클리프 데뷔 뒤 진행한 공식 후열 합방이에요. 질문 시간과 ‘모르는 물건 팔기’가 원본 제목에 담겨 있어요.
8DNraivZD3U|추석에 진행한 ‘송편 대작전’ 합방이에요. 명절을 주제로 한 리스텔라 공식 방송 기록이에요.
DLVMl9XQ2Io|클리프 릴레이 노래방의 단체 싱크룸이에요. 개인 순서 뒤 함께한 공식 노래방 기록을 볼 수 있어요.
R0KcgJS2KwY|리스텔라의 피코파크 2 게임 합방이에요. 공식 다시보기 채널에 남겨진 공동 게임 방송이에요.
S8WTwvJ1ghQ|‘괴식탐구회’라는 제목으로 진행한 리스텔라 합방이에요. 어떤 음식과 반응이 나왔는지는 원본에서 만나볼 수 있어요.
_VThNqjyYVo|클리프 100일을 기념한 ‘이상한 초대’ 합방이에요. 개인 100일 방송과 별도로 남겨진 공식 기록이에요.
sp4gU0LnG5o|새해를 맞아 진행한 리스텔라 듀엣 가요제예요. 함께 노래한 공식 기획 방송을 다시 볼 수 있어요.
RWXOVHS-JpQ|‘가장 집 정리를 안 할 것 같은 스텔라’를 주제로 한 월간 리스텔라 2월호예요. 결과는 원본 방송에서 확인할 수 있어요.
Mk45wdTss4w|‘벚꽃놀이를 같이 가고 싶은 스텔라’를 주제로 한 월간 리스텔라 3월호예요. 봄을 맞은 공식 기획 기록이에요.
R_eKP34HWJQ|‘만우절 장난을 가장 잘 칠 것 같은 스텔라’를 다룬 월간 4월호예요. 멤버별 만우절 방송과는 별개의 공식 기획이에요.
aon-V07e0OI|‘리스텔라 유치원 학부모 참관수업’이라는 제목의 공식 방송이에요. 당시 출연 구성을 그대로 담은 영상으로 이어져요.
m_nSA76fd3g|단밍과 쿠비의 일주일 패션 대결을 다룬 공식 기획이에요. 대결 결과와 의상은 원본에서 볼 수 있어요.
BQpc5CHIjR4|단밍과 쿠비가 함께한 1주년 기념 방송이에요. 각자의 후열 방송과 구분해 공동 방송을 보관했어요.
g9hq8iHtHF4|‘루체테 문화센터’라는 이름으로 진행한 월간 리스텔라예요. 공식 채널에 남은 기획 방송으로 이어져요.
lTRZxyn12FI|2025년 9월 30일의 리스텔라 공지 방송이에요. 당시 발표 내용은 날짜가 다른 최신 공지와 구분해서 볼 수 있어요.
VKrYwlN09n4|야토와 샤메이의 일주일 패션 대결이에요. 원본 제목에는 단밍·쿠비·네무·만디·샤메이와 함께한 방송으로 안내돼 있어요.
YfuY45kWNV8|VOGI와 함께 한국·말레이시아 과자를 리뷰한 방송이에요. 공식 채널에 한국어·영어 표기로 보관되어 있어요.
Sk9JactTkVw|설을 맞아 커버곡과 굿즈 공개, 훈민정음 윷놀이를 진행한 공식 특집이에요. 명절의 공동 방송을 꺼내볼 수 있어요.
l8MqWJ8kTuc|리스텔라 퀴즈왕을 다룬 월간 공식 방송이에요. 누가 어떤 문제를 맞혔는지는 원본에서 확인할 수 있어요.
Qvp5rP24HN4|‘진짜를 찾아라! 3등분의 단밍 & 쿠비’라는 공식 기획이에요. 단밍과 쿠비를 주제로 한 다시보기를 연결했어요.
5hMTmRiDI-w|신입생 오리엔테이션을 주제로 한 월간 리스텔라예요. 영상 속 당시의 출연 구성과 방송을 그대로 볼 수 있어요.
hhk0DDqlxG8|리스텔라와 그로서리 서울의 라이브 커머스 방송 기록이에요. 당시 판매 방송을 다시 보는 페이지이며 현재 판매 여부를 뜻하지 않아요.
9TnZPG06Nj4|서새봄의 스텔라 상담소를 주제로 진행한 월간 리스텔라예요. 구체적인 상담 내용은 원본 방송에 남아 있어요.
mSvIP6EjvSc|유네·도리·후와가 함께한 100일 기념 방송이에요. 각자 채널의 후열 기록과 함께 볼 수 있어요.
cEeVNDSjL9c|단밍과 쿠비가 함께한 두 번째 주년 기념 방송이에요. 전년도 공동 1주년 다음에 이어지는 기록이에요.
3hIAel12pbw|2026년 하반기 리스텔라 공지 방송이에요. 당시의 발표와 이후 실제 공개 방송을 날짜별로 구분해 보관했어요.
"""

PALETTES = ['a46632', 'b3617f', '5f885b', '8b729f', 'c27d69', '4f8a9f', '405878']
JUMPS = {
    'qC8rhRWMtw8': ('돌잡이 · 2:41:18', 9678),
    'rcYgpdoRcBE': ('방 소개 · 21:38', 1298),
    'gj_0ibrZmds': ('스토리 · 05:44', 344),
    '2p_wERFMpSU': ('팬네임 정하기 · 1:22:42', 4962),
    'V8Mo6j1EwBM': ('햄님 설문 · 1:04:31', 3871),
    'CWKoXxh6ItE': ('담력시험 · 1:06:24', 3984),
}


def source_date(detail, requested):
    title = detail['title']
    if detail.get('live_open_date'):
        date = detail['live_open_date'][:10]
        assert date == requested, (detail['id'], date, requested)
        return date, 'broadcast', '치지직 다시보기의 방송 시작일 기준'
    if requested:
        y, m, d = requested.split('-')
        forms = [f'{y}.{m}.{d}', f'{y[2:]}.{m}.{d}', f'{y[2:]}{m}{d}']
        if any(form in title for form in forms):
            return requested, 'broadcast', '원본 다시보기 제목에 적힌 방송 날짜'
    # Uploads are not silently re-labelled as the broadcast date.
    value = datetime.datetime.fromisoformat(detail['publish_date'])
    date = value.astimezone(datetime.timezone(datetime.timedelta(hours=9))).date().isoformat()
    return date, 'published', '영상 게시일(한국 시간) · 정확한 방송일 미확인'


def main():
    selected = json.loads((DEST/'selected_events.json').read_text(encoding='utf-8'))
    details = {r['id']: r for r in json.loads((DEST/'selected_details.json').read_text(encoding='utf-8'))}
    channels = json.loads((DEST/'channels.json').read_text(encoding='utf-8'))
    summaries = dict(line.split('|', 1) for line in SUMMARIES.strip().splitlines())
    volumes = []
    for i, channel in enumerate(channels):
        owner = channel['id']
        volume = {'id': owner, 'title': channel['name'], 'subtitle': '공식 합방과 기획' if owner == 'official' else '방송에서 함께한 날들',
                  'color': PALETTES[i], 'intro': '기념일·공개 방송·특별 기획을 날짜순으로 모았어요.', 'entries': []}
        for row in (r for r in selected if r['owner'] == owner):
            primary = row['sources'][0]
            key = primary['id']
            metadata = details[key]
            assert metadata['verified'], key
            date, date_kind, date_note = source_date(metadata, row['date'])
            sources = []
            for n, raw in enumerate(row['sources']):
                assert details[raw['id']]['verified'], raw['id']
                label = '공식 다시보기' if owner == 'official' else '다시보기'
                if len(row['sources']) == 2:
                    if key == '16061701': label = '치지직 다시보기' if n == 0 else '공개 영상'
                    elif key == 'p0y1Kr795lg': label = '예열 방송' if n == 0 else '후열 방송'
                    elif key == 'fSBoqOuOPuU': label = '생일 본방송' if n == 0 else '후열 대화'
                    else: label = f'다시보기 {n+1}부'
                sources.append({'label': label, 'url': raw['url'], 'kind': 'official_vod' if owner == 'official' else 'member_vod'})
            note = '방송 제목·설명으로 확인한 기록이에요. 자세한 내용은 원본에서 볼 수 있어요.'
            if key in JUMPS and len(sources) < 2:
                label, seconds = JUMPS[key]
                # Each jump must occur verbatim in a channel-provided timestamp line.
                timestamp = label.split(' · ')[-1]
                assert any(timestamp in line for line in metadata['timestamps']), (key, timestamp)
                assert seconds < metadata['duration_seconds']
                sources.append({'label': label, 'url': primary['url']+f'&t={seconds}s', 'kind': 'channel_timestamp'})
                note = '바로가기는 원본 영상 설명의 시간표를 기준으로 연결했어요.'
            if owner == 'official' and ('@니우니우' in metadata['description'] or '@lobo_moonlit' in metadata['description']):
                note = '당시 출연진이 담긴 기록이에요. 현재 멤버 구성으로 바꾸어 소개하지 않았어요.'
            volume['entries'].append({'id': owner+'_'+key, 'title': row['title'],
                'date': date.replace('-', '.')+(' · 게시' if date_kind == 'published' else ''),
                'sort_date': date, 'date_kind': date_kind, 'date_note': date_note,
                'status': 'recorded', 'members': [] if owner == 'official' else [owner],
                'body': summaries[key], 'note': note, 'sources': sources,
                'original_titles': [details[s['id']]['title'] for s in row['sources']],
                'verification': {'checked_on': '2026-11-15', 'level': 'title_description', 'full_video_watched': False,
                                 'detail_files': ['details/'+s['id']+'.json' for s in row['sources']]}})
        volume['entries'].sort(key=lambda e: (e['sort_date'], e['id']))
        volumes.append(volume)
    # Preserve the existing dated notice, explicitly separate from completed records.
    existing = json.loads((ROOT/'assets/records/library_events.json').read_text(encoding='utf-8'))
    notice = next(e for v in existing['volumes'] for e in v['entries'] if e['id'] == 'danming_3d_notice')
    notice.update(sort_date='2026-11-21', date_kind='announced', verification={
        'checked_on': '2026-11-15', 'level': 'channel_schedule_title', 'full_video_watched': False})
    volumes[1]['entries'].append(notice)
    catalog = {'checked_on': '2026-11-15', 'audit_scope': 'public_listing_and_selected_metadata',
               'public_video_links': 3772, 'recorded_entries': 100, 'announcement_entries': 1,
               'volumes': volumes}
    save('library_events_proposed.json', catalog)
    counts = {v['title']: len(v['entries']) for v in volumes}
    print(json.dumps(counts, ensure_ascii=False))
    # Keep a non-runtime, readable report with every primary source and verification scope.
    lines = ['리스텔라 방송 기록 조사 · 2026.11.15', '',
        '조사 범위: 현재 멤버 6명과 리스텔라 공식, 총 7개 주체의 본채널·다시보기 채널.',
        '유튜브 동영상·라이브 탭과 치지직 공개 목록 35개 표면을 마지막 페이지까지 조사.',
        '공개 영상 링크 3,772개. 본채널 편집본과 다시보기, 같은 방송의 시점별 업로드가 포함됨.',
        '제목 중심 1차 후보 405개에서 기록 100건(원본 106개 링크)을 선별. 예고 1건 별도.',
        '100건은 서로 다른 방송 100회라는 뜻이 아님. 같은 합방의 멤버 시점은 각 책에 기록.',
        '선별한 106개 원본의 제목·설명·게시 정보 확인 완료. 전체 영상을 처음부터 끝까지 시청한 조사는 아님.',
        '비공개·삭제·유료·접근제한 영상과 Shorts는 조사 범위 밖.',
        '선정 기준: 데뷔·주년·생일·신의상·3D·팬네임·첫 노래방·명절·만우절·공식 기획·주요 합방.',
        '제외 예: 게임 자체의 주년, 단순 공개 예고, 다른 사람의 생일, 제목의 우연한 키워드 일치.',
        '여러 부로 나뉜 영상은 한 기록에 묶었고, 같은 제목의 타 플랫폼 사본은 대표 링크로 정리.',
        '날짜 근거가 방송 제목/시작 정보에 없으면 영상 게시일로 명시. 당일 방송으로 추정하지 않음.',
        '새 7권 책장과 게임 반영은 사용자 시안 확인 대기. 현재 결과는 검토용 파일.', '']
    for volume in volumes:
        lines += [f'[{volume["title"]}] {len(volume["entries"])}건', '']
        for entry in volume['entries']:
            lines += [f'{entry["date"]}  {entry["title"]}', entry['body'], entry['date_note']]
            lines += [f'  {s["label"]}: {s["url"]}' for s in entry['sources']]
            lines += ['']
    (DEST/'방송 기록 조사 결과.txt').write_text('\n'.join(lines)+'\n', encoding='utf-8')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main()
