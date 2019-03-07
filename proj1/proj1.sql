-- Q5: program enrolments from 10s1
create or replace view Q5a(num)
as
--... SQL statements, possibly using other views/functions defined by you ...
select count(pe."id")
from program_enrolments pe
	join stream_enrolments se on (se.partof=pe."id")
	join students st on (st."id"=pe.student)
	join semesters sm on (sm."id"=pe.semester)
	join streams str on (str."id"=se.stream)
where st.stype='intl'
	and sm."year"='2010'
	and sm.term='S1'
	and str.code='SENGA1'
;

create or replace view Q5b(num)
as
--... SQL statements, possibly using other views/functions defined by you ...
select count(pe."id")
from program_enrolments pe
	join students st on (st."id"=pe.student)
	join semesters sm on (sm."id"=pe.semester)
	join programs pr on (pr."id"=pe.program)
where st.stype='local'
	and sm."year"='2010'
	and sm.term='S1'
	and pr.code='3978'
;

create or replace view Q5c(num)
as
--... SQL statements, possibly using other views/functions defined by you ...
select count(pe."id")
from program_enrolments pe
	join semesters sm on (sm."id"=pe.semester)
	join programs pr on (pr."id"=pe.program)
	join orgunits org on (org."id"=pr.offeredby)
where sm."year"='2010'
	and sm.term='S1'
	and org."name"='Faculty of Engineering'
;



-- Q6: course CodeName
create or replace function
	Q6(text) returns text
as
$$
--... SQL statements, possibly using other views/functions defined by you ...
	select (code || ' ' || name)::text
	from subjects
	where code=$1;
$$ language sql
;



create or replace function
	find_perc_growth(inyear integer, interm char(2)) returns float
as $$
declare
	newyear integer;
	newterm char(2);
	retresult integer;
begin
	if interm='S1' then
		newyear := inyear - 1;
		newterm := 'S2';
	elsif interm='S2' then
		newyear := inyear;
		newterm := 'S1';
	end if;
	select count(sm."year") into retresult
	from semesters sm
		join courses co on (co.semester=sm."id")
		join course_enrolments ce on (ce.course=co."id")
		join subjects su on (su."id"=co.subject)
	where sm.term=newterm and sm."year"=newyear and
		su."name"='Database Systems'
	group by sm."year", sm.term
	order by sm."year";
	return retresult::float;
end;
$$ language 'plpgsql';

-- Q7: Percentage of growth of students enrolled in Database Systems
create or replace view Q7(year, term, perc_growth)
as
--... SQL statements, possibly using other views/functions defined by you ...
select sm."year", sm.term, cast(count(sm."year")/(select find_perc_growth(sm."year", sm.term)) as numeric(4,2)) as perc_growth
from semesters sm
	join courses co on (co.semester=sm."id")
	join course_enrolments ce on (ce.course=co."id")
	join subjects su on (su."id"=co.subject)
where su."name"='Database Systems'
group by sm."year", sm.term
order by sm."year"
offset 1;
;



-- Q8: Least popular subjects
create or replace view offrings(subject, numoff)
as
	select subject, count(subject) as numoff
	from courses
	group by subject
	order by subject
;
create or replace view enroll(course, numen)
as
	select course, count(course) as num
	from course_enrolments
	group by course
	order by course
;

create or replace view Q8(subject)
as
--... SQL statements, possibly using other views/functions defined by you ...
select su.code, su.name
from subjects su
where su.id = any
(select co.subject
from enroll en
	join courses co on (co."id"=en.course)
	join offrings ofr on (co.subject=ofr.subject)
	join subjects su on (su."id"=co.subject)
where en.numen<20 and ofr.numoff>20
group by co.subject
having count(co.subject)<20
)
order by su.code
;



create or replace view total(student, year, term, mark)
as
select ce.student, se."year", se.term, ce.mark
from semesters se
	join courses co on (co.semester=se."id")
	join course_enrolments ce on (ce.course=co."id")
	join subjects su on (su."id"=co.subject)
where su."name"='Database Systems'
order by se."year", se.term;

create or replace view allstu(allyear, allterm, allnum)
as
select year, term, count(*)
from total
where mark>=0
group by year, term;

create or replace view passstu(passyear, passterm, passnum)
as
select year, term, count(*)
from total
where mark>=50
group by year, term;

create or replace view s1(year, s1_pass_rate)
as
select ps.passyear, cast(ps.passnum::float/al.allnum::float as numeric(4,2))
from passstu ps
	join allstu al on (al.allyear=ps.passyear and al.allterm=ps.passterm)
where ps.passterm='S1';

create or replace view s2(year, s2_pass_rate)
as
select ps.passyear, cast(ps.passnum::float/al.allnum::float as numeric(4,2))
from passstu ps
	join allstu al on (al.allyear=ps.passyear and al.allterm=ps.passterm)
where ps.passterm='S2';

-- Q9: Database Systems pass rate for both semester in each year
create or replace view Q9(year, s1_pass_rate, s2_pass_rate)
as
--... SQL statements, possibly using other views/functions defined by you ...
select substring(s1.year::text,3,4), s1.s1_pass_rate, s2.s2_pass_rate
from s1
	join s2 on (s2.year=s1.year)
;



-- Q10: find all students who failed all black series subjects
-- course_code: return the tuple containing all course offerings
create or replace view course_code(code,year,term)
as
select su.code, se.year, se.term
from subjects su
	join courses co on (co.subject=su.id)
	join semesters se on (se.id=co.semester)
;

-- major_term: return the tuple containing every term (i.e. S1 and S2) from 2002 to 2013
create or replace view major_term(year, term)
as
select distinct se.year, se.term
from courses co
	join semesters se on (se.id=co.semester)
where se.year between 2002 and 2013
	and se.term not like 'X%'
order by se.year, se.term
;

-- failedset: return a set of courses begin with 'COMP93' and offered in major terms
create or replace view failedset(code)
as
select distinct cc.code
from course_code cc
where cc.code like 'COMP93%'
	and not exists(
		(select year,term from major_term)
		except
		(select year,term from course_code where code = cc.code)
	)
;

create or replace view helper(code, unswid, name)
as
select distinct fs.code, pe.unswid, pe.name
from failedset fs
	join subjects su on (su.code=fs.code)
	join courses co on (co.subject=su.id)
	join course_enrolments ce on (ce.course=co.id)
	join people pe on (pe.id=ce.student)
where ce.mark<50
;

create or replace view Q10(zid, name)
as
--... SQL statements, possibly using other views/functions defined by you ...
select 'z'||unswid, name
from helper
group by unswid, name
having count(*)=(select count(*) from failedset)
;