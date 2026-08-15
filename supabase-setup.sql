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
create policy if not exists "public can read events"
  on events for select
  using (true);

-- 쓰기(INSERT/UPDATE/DELETE)는 기본적으로 막혀 있음(정책 없음 = 거부).
-- 일정은 Supabase 대시보드의 Table Editor에서 로그인한 관리자만 직접 수정하세요.

-- 예시 데이터 (원하는 대로 수정/삭제하세요)
insert into events (event_id, panel, sort_order, time, title, detail) values
  ('2026-08-sua', 'd1', 1, '09:00-10:00', '집합 및 출발', '정문 앞에서 모임'),
  ('2026-08-sua', 'd1', 2, '12:00-13:00', '점심식사', null),
  ('2026-08-sua', 'd2', 1, '08:00-08:30', '기상 및 아침식사', null);


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
-- 1. 이 events 테이블에 새 event_id 값으로 일정 행들을 추가 (Table Editor 또는 insert 문)
-- 2. index.html 을 새 폴더(예: 2027-01-newevent/)에 복사하고 CONFIG.eventSlug 를 새 값으로 수정
-- 3. 루트 index.html(허브 페이지)의 EVENTS 배열에 새 이벤트 한 줄 추가
