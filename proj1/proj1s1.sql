-- COMP3311 17s1 Project 1
--
-- MyMyUNSW Solution Template


-- Q1: buildings that have more than 30 rooms
create or replace view Q1(unswid, name)
as
--... SQL statements, possibly using other views/functions defined by you ...
	SELECT unswid, name
	FROM buildings
	WHERE id = ANY(SELECT building 
		    	   FROM rooms GROUP BY building HAVING count(building) > 30)
;



-- Q2: get details of the current Deans of Faculty
create or replace view Q2(name, faculty, phone, starting)
as
--... SQL statements, possibly using other views/functions defined by you ...
	select t1.name, t2.longname, t3.phone, t4.starting
	from people t1, 
	orgunits t2, 
	staff t3, 
	affiliations t4
	where role in 
		(select id
		from staff_roles
		where name = 'Dean')
		and t2.id = t4.orgunit and t2.utype = 1 and t4.ending is null
		and t1.id = t3.id and t3.id = t4.staff and t4.orgunit = t2.id
;



-- Q3: get details of the longest-serving and shortest-serving current Deans of Faculty
create or replace view Q3(status, name, faculty, starting)
as
--... SQL statements, possibly using other views/functions defined by you ...
	(select 'Longest serving' as status, name, faculty, starting from Q2 where starting in
	(select min(starting) from Q2))
	union
	(select 'Shortest serving' as status, name, faculty, starting from Q2 where starting in
	(select max(starting) from Q2))
;



-- Q4 UOC/ETFS ratio
create or replace view Q4(ratio,nsubjects)
as
--... SQL statements, possibly using other views/functions defined by you ...
	SELECT CAST((uoc/eftsload) AS NUMERIC(4,1)) AS ratio, count(*)
	FROM subjects 
	WHERE (uoc != 0 AND uoc IS NOT NULL) AND (eftsload != 0 AND eftsload IS NOT NULL)
	GROUP BY ratio
;






