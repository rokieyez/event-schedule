-- Supabase 프로젝트의 SQL Editor에서 실행하세요.

-- ============================================================
-- 처음 테이블을 만드는 경우 (신규 Supabase 프로젝트)
-- ============================================================
create table if not exists events (
  id bigint generated always as identity primary key,
  event_id text not null,     -- 이벤트 구분값. index.html CONFIG.eventSlug 와 일치해야 함 (예: '2026-08-sua')
  panel text not null,        -- index.html CONFIG.panels 의 id 값과 일치해야 함 (예: 'd1')
  sort_order int not null default 0,  -- 같은 panel 안에서의 정렬 순서
  time text,                  -- 예: '09:00-09:30'
  title text not null,        -- 예: '아침식사'
  detail text,                -- 예: '식당 1층'
  created_at timestamptz default now()
);

-- 행 단위 보안(RLS) 활성화
alter table events enable row level security;

-- 누구나 읽기(SELECT)는 허용 — 공개 일정 페이지이므로
create policy "public can read events"
  on events for select
  using (true);

-- 쓰기(INSERT/UPDATE/DELETE)는 기본적으로 막혀 있음(정책 없음 = 거부).
-- 로그인(Supabase Auth)한 관리자만 admin.html에서 추가/수정/삭제 가능하도록 허용
create policy "authenticated can write events"
  on events for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- 예시 데이터 (원하는 대로 수정/삭제하세요)
insert into events (event_id, panel, sort_order, time, title, detail) values
  ('2026-08-sua', 'd1', 1, '09:00-10:00', '집합 및 출발', '정문 앞에서 모임'),
  ('2026-08-sua', 'd1', 2, '12:00-13:00', '점심식사', null),
  ('2026-08-sua', 'd2', 1, '08:00-08:30', '기상 및 아침식사', null);


-- ============================================================
-- 헤더(아이콘/제목/부제목)를 Supabase에서 직접 수정할 수 있게 하는 테이블
-- 이벤트당 딱 한 행만 있으면 됨. 행이 없으면 index.html의 CONFIG 기본값이 그대로 쓰임
-- ============================================================
create table if not exists event_meta (
  event_id text primary key,  -- index.html CONFIG.eventSlug 와 일치해야 함 (예: '2026-08-sua')
  icon text,                  -- 헤더 상단 아이콘 이모지 (예: '🗓️')
  org_name text,              -- 큰 제목 (예: '수아연아랑')
  event_name text,            -- 부제목 앞부분 (예: '여름 수련회')
  date_range_text text,       -- 부제목 뒷부분 (예: '2026. 8. 14(금) ~ 8. 17(월)')
  updated_at timestamptz default now()
);

alter table event_meta enable row level security;

create policy "public can read event_meta"
  on event_meta for select
  using (true);

-- 지금 이벤트의 헤더 값 (필요한 값만 채우면 됨 — 나머지는 CONFIG 기본값 사용)
insert into event_meta (event_id, icon, org_name, event_name, date_range_text) values
  ('2026-08-sua', '🗓️', '수아연아랑', '일정명', '2026. 8. 14(금) ~ 8. 17(월)');


-- ============================================================
-- 이미 events 테이블이 있고 event_id 컬럼만 추가하는 경우
-- (여러 이벤트를 앞으로 계속 만들기로 하면서 기존 테이블을 재사용할 때 1회만 실행)
-- ============================================================
-- 1) 컬럼 추가 (일단 nullable로)
alter table events add column if not exists event_id text;

-- 2) 기존 행들을 첫 번째 이벤트로 채워넣기 — 'YOUR_FIRST_EVENT_SLUG'를 실제 slug로 바꿔서 실행
-- update events set event_id = 'YOUR_FIRST_EVENT_SLUG' where event_id is null;

-- 3) 다 채워진 걸 확인한 뒤, 앞으로는 비워둘 수 없게 고정
-- alter table events alter column event_id set not null;


-- ============================================================
-- 새 이벤트를 추가할 때마다
-- ============================================================
-- 1. events 테이블에 새 event_id 값으로 일정 행들을 추가 (Table Editor 또는 insert 문)
-- 2. event_meta 테이블에 새 event_id로 헤더(아이콘/제목/부제목) 행 추가 (선택사항, 없으면 CONFIG 기본값 사용)
-- 3. index.html 을 새 폴더(예: 2027-01-newevent/)에 복사하고 CONFIG.eventSlug 를 새 값으로 수정
-- 4. 루트 index.html(허브 페이지)의 EVENTS 배열에 새 이벤트 한 줄 추가
