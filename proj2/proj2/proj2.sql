-- COMP3311 17s1 Project 2
--
-- Section 1 Template

--Q1: ...
-- create a view containing all the incorrect record
create or replace view uoc_compare(code, uoc, eftsload, eftsl)
as
select code, uoc, eftsload, (uoc::float4/48)
from subjects
;

create type IncorrectRecord as (pattern_number integer, uoc_number integer);

create or replace function Q1(pattern text, uoc_threshold integer) 
	returns IncorrectRecord
as $$
--... SQL statements, possibly using other views/functions defined by you ...
declare
	result_record IncorrectRecord;
begin
	select count(*) into result_record.pattern_number
	from uoc_compare
	where abs(eftsl-eftsload) > 0.001 and code like pattern;
	select count(*) into result_record.uoc_number
	from uoc_compare
	where abs(eftsl-eftsload) > 0.001 and code like 'ECO%' and uoc > uoc_threshold ;
	return result_record;
end;
$$ language plpgsql;

-- select * from q1(‘ECO%’, 6);
-- end of Q1



-- Q2: ...
-- PgSQL funtion of getting rank of each student
create or replace function get_rank(cid integer, cterm char(4), cmark integer)
	returns integer
as $$
declare
	ret_rank integer;
begin
	select subquery.rank into ret_rank
	from
		(select co.id as id, ((substring(se.year::text,3,4)||lower(se.term))::char(4)) as term,
			su.code as code, su.name as name, su.uoc as uoc,
			ce.mark as mark, ce.grade as grade, rank() over(order by ce.mark desc) as rank
		from people pe -- input defined by p.unswid
			join course_enrolments ce on (ce.student=pe.id)
			join courses co on (co.id=ce.course)
			join subjects su on (su.id=co.subject)
			join semesters se on (se.id=co.semester)
		where co.id = cid and ce.mark is not null
		group by co.id, se.year, se.term, su.code, su.name, su.uoc, ce.mark, ce.grade) as subquery
	where subquery.mark = cmark and subquery.term = cterm;
	return ret_rank;
end;
$$ language plpgsql;

-- PgSQL function of getting the total number of students who enrolled in
create or replace function get_total(cid integer, cterm char(4))
	returns integer
as $$
declare
	ret_total integer;
begin
	select count(*) into ret_total
	from
		(select co.id as id, ((substring(se.year::text,3,4)||lower(se.term))::char(4)) as tterm,
			su.code as code, su.name as name, su.uoc as uoc,
			ce.mark as mark, ce.grade as grade
		from people pe -- input defined by p.unswid
			join course_enrolments ce on (ce.student=pe.id)
			join courses co on (co.id=ce.course)
			join subjects su on (su.id=co.subject)
			join semesters se on (se.id=co.semester)
		where co.id = cid and ce.mark is not null
		group by co.id, se.year, se.term, su.code, su.name, su.uoc, ce.mark, ce.grade) as subquery
	where subquery.tterm = cterm;
	return ret_total;
end;
$$ language plpgsql;

create type TranscriptRecord as (cid integer, term char(4), code char(8), name text, uoc integer, mark integer, grade char(2), rank integer, totalEnrols integer);

create or replace function Q2(stu_unswid integer)
	returns setof TranscriptRecord
as $$
declare
	result_record TranscriptRecord;
begin
	for result_record in
		select co.id, (substring(se.year::text,3,4)||lower(term))::char(4),
			su.code, su.name, su.uoc, ce.mark, ce.grade
		from people pe -- input defined by p.unswid
			join course_enrolments ce on (ce.student=pe.id)
			join courses co on (co.id=ce.course)
			join subjects su on (su.id=co.subject)
			join semesters se on (se.id=co.semester)
		where pe.unswid = stu_unswid
		group by co.id, se.year, se.term, su.code, su.name, su.uoc, ce.mark, ce.grade
	loop 
		select * into result_record.rank
		from get_rank(result_record.cid, result_record.term, result_record.mark);
		select * into result_record.totalEnrols
		from get_total(result_record.cid, result_record.term);
		if (result_record.grade not in ('SY', 'RS', 'PT', 'PC', 'PS', 'CR', 'DN', 'HD', 'A', 'B', 'C', 'D', 'E')) then
			result_record.uoc := 0;
		end if;
		return next result_record;
	end loop;
end;
$$ language plpgsql;

-- select * from q2(2220747);
-- end of Q2


-- Q3: ...
-- create view for staffs who have delivered course
create or replace view staff_view(org_id, sub_id, course_id, staff)
as
	select org.id, su.id, co.id, cs.staff
	from subjects su
		join courses co on (su.id = co.subject)
		join course_staff cs on (cs.course = co.id)
		join orgunits org on (su.offeredby = org.id)
	where cs.role = '1870' or cs.role = '3003' 
	order by org.id, cs.staff;

-- SQL function include all the subOrganizations' id
create or replace function sub_organization(integer)
 	returns setof integer
as
$$
	with recursive sub_orgs as (
		(select member
		from orgunit_groups
		where member = $1)
		union 
		(select og.member
		from orgunit_groups og
		inner join sub_orgs s on (s.member = og.owner))
	)
	select member
	from sub_orgs;
$$ language sql;

create or replace function staff_subs(integer) 
	returns table(
		sub_id integer,
		count bigint,
		staff integer)
as
$$
	select sub_id, count(course_id), staff
	from (
		select sub_id, course_id, staff
		from staff_view
		where org_id in 
			(select * 
			from sub_organization($1))) as subquery
	group by sub_id, staff
	order by staff;
$$ language sql;

create or replace function build_teaching_record(org_id integer, staff_id integer,num_times integer)
 returns text
as $$
declare
	teaching_record text := '';
	modifier text;
	sub_code text;
	offered_by integer;
	nr integer;
	org text;
	recordings record;
begin
	for recordings in 
		select sub_id, count 
		from staff_subs($1) 
		where staff = $2 and count > $3 
		order by sub_id
	loop
		select subjects.code, subjects.offeredby into sub_code, offered_by from subjects where id = recordings.sub_id;
		nr := recordings.count;
		select name into org from orgunits where id = offered_by;
		modifier := '';
		modifier := sub_code||', '||nr||', '||org||''||E'\n'; 	-- add newline symbol to the endof result
		teaching_record := teaching_record||''||modifier;
	end loop;
 return teaching_record;
end;
$$ language plpgsql;

create type TeachingRecord as (unswid integer, staff_name text, teaching_records text);

create or replace function Q3(org_id integer, num_sub integer, num_times integer)
 returns setof TeachingRecord
as $$
declare
	sub_count integer;
	myrec record;
	myresult TeachingRecord;
begin
	for myrec in 
		select distinct staff 
		from staff_subs(org_id) 
		where count > num_times
	loop
		select count(*) into sub_count 
		from staff_subs(org_id)
		where staff = myrec.staff;
		if (sub_count > num_sub) then
			select people.unswid, people.name into myresult.unswid, myresult.staff_name 
			from people 
			where id = myrec.staff;
			myresult.teaching_records := build_teaching_record(org_id, myrec.staff, num_times);
			return next myresult;
		end if;
	end loop;
end;
$$ language plpgsql;

-- select * from q3(52, 20, 8);
-- end of Q3


