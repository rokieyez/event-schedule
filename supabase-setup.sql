-- Supabase 프로젝트의 SQL Editor에서 실행하세요.

create table if not exists events (
  id bigint generated always as identity primary key,
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
-- 일정은 Supabase 대시보드의 Table Editor에서 로그인한 관리자만 직접 수정하세요.
-- 만약 나중에 특정 인증된 사용자만 수정 가능하게 하려면 아래처럼 정책을 추가하면 됩니다.
-- create policy "authenticated can write events"
--   on events for all
--   using (auth.role() = 'authenticated')
--   with check (auth.role() = 'authenticated');

-- 예시 데이터 (원하는 대로 수정/삭제하세요)
insert into events (panel, sort_order, time, title, detail) values
  ('d1', 1, '09:00-10:00', '집합 및 출발', '정문 앞에서 모임'),
  ('d1', 2, '12:00-13:00', '점심식사', null),
  ('d2', 1, '08:00-08:30', '기상 및 아침식사', null);
