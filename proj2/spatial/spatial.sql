-- COMP3311 17s1 Project 2
--
-- Section 2 Template

--------------------------------------------------------------------------------
-- Q4
--------------------------------------------------------------------------------

create type PointRecord as (x integer, y integer);

create or replace function has_domination(xaxis integer, yaxis integer, dataset text)
	returns setof PointRecord
as $$
declare
	my_record PointRecord;
begin
	for my_record in execute 
		'select x, y
		from ' || quote_ident(dataset) ||' 
		where (x >= $1 and y > $2) or (x > $1 and y >= $2)'
		using xaxis, yaxis
	loop
		return next my_record;
	end loop;
	
end;
$$ language plpgsql;

create or replace function skyline_op(dataset text) 
    returns setof PointRecord
as $$
declare
	my_record PointRecord;
	ret_result PointRecord;
begin	
	for my_record in execute format('select * from %I', dataset)
	loop
		perform from has_domination(my_record.x, my_record.y, dataset);
		if not found then
			ret_result.x := my_record.x;
			ret_result.y := my_record.y;
			return next ret_result;
		end if;

	end loop;
end;
$$ language plpgsql;

drop function if exists skyline_naive(text) cascade;

-- This function calculates skyline in O(n^2)
create or replace function skyline_naive(dataset text) 
    returns integer 
as $$
--... SQL statements, possibly using other views/functions defined by you ...
declare
	counter integer;
begin
	execute format('select count(*) from skyline_op(''%I'');',dataset) into counter;
	execute format('create or replace view %I'||'_skyline_naive(x,y) as select * from skyline_op(''%I'')', dataset, dataset);
	return counter;
end;
$$ language plpgsql;

--------------------------------------------------------------------------------
-- Q5
--------------------------------------------------------------------------------

create or replace function has_domination(xaxis integer, yaxis integer, dataset text)
	returns setof PointRecord
as $$
declare
	my_record PointRecord;
begin
	for my_record in execute 
		'select x, y
		from ' || quote_ident(dataset) ||' 
		where (x >= $1 and y > $2) or (x > $1 and y >= $2)'
		using xaxis, yaxis
	loop
		return next my_record;
	end loop;
	
end;
$$ language plpgsql;

create or replace function k_skyband_op(dataset text) 
    returns setof PointRecord
as $$
declare
	counter integer;
	my_record PointRecord;
	ret_result PointRecord;
begin	
	for my_record in execute format('select * from %I', dataset)
	loop
		select count(*) into counter from has_domination(my_record.x, my_record.y, dataset);
		-- given k parameter here
		if (counter < 1) then
			ret_result.x := my_record.x;
			ret_result.y := my_record.y;
			return next ret_result;
		end if;

	end loop;
end;
$$ language plpgsql;

drop function if exists skyline(text) cascade;

-- This function calculates skyline in O(n^2)
create or replace function skyline(dataset text)  
    returns integer 
as $$
--... SQL statements, possibly using other views/functions defined by you ...
declare
	counter integer;
begin
	execute format('select count(*) from k_skyband_op(''%I'');',dataset) into counter;
	execute format('create or replace view %I'||'_skyline(x,y) as select * from k_skyband_op(''%I'')', dataset, dataset);
	return counter;
end;
$$ language plpgsql;

--------------------------------------------------------------------------------
-- Q6
--------------------------------------------------------------------------------

create or replace function has_domination(xaxis integer, yaxis integer, dataset text)
	returns setof PointRecord
as $$
declare
	my_record PointRecord;
begin
	for my_record in execute 
		'select x, y
		from ' || quote_ident(dataset) ||' 
		where (x >= $1 and y > $2) or (x > $1 and y >= $2)'
		using xaxis, yaxis
	loop
		return next my_record;
	end loop;
	
end;
$$ language plpgsql;

create or replace function k_skyband(dataset text, k integer) 
    returns setof PointRecord
as $$
declare
	counter integer;
	my_record PointRecord;
	ret_result PointRecord;
begin	
	for my_record in execute format('select * from %I', dataset)
	loop
		select count(*) into counter from has_domination(my_record.x, my_record.y, dataset);
		if (counter < k) then
			ret_result.x := my_record.x;
			ret_result.y := my_record.y;
			return next ret_result;
		end if;

	end loop;
end;
$$ language plpgsql;

drop function if exists skyband_naive(text, integer) cascade;

-- This function calculates skyline in O(n^2)
create or replace function skyband_naive(dataset text, k integer)  
    returns integer 
as $$
--... SQL statements, possibly using other views/functions defined by you ...
declare
	counter integer;
begin
	execute 'select count(*) from k_skyband($1,$2);' into counter using dataset, k;
	execute format('
		create or replace view %I'||'_skyband_naive(x,y)'||' as select * from k_skyband(''%I'', %L)', dataset, dataset, k);
	return counter;
end;
$$ language plpgsql;

--------------------------------------------------------------------------------
-- Q7
--------------------------------------------------------------------------------

create or replace function has_domination(xaxis integer, yaxis integer, dataset text)
	returns setof PointRecord
as $$
declare
	my_record PointRecord;
begin
	for my_record in execute 
		'select x, y
		from ' || quote_ident(dataset) ||' 
		where (x >= $1 and y > $2) or (x > $1 and y >= $2)'
		using xaxis, yaxis
	loop
		return next my_record;
	end loop;
	
end;
$$ language plpgsql;

create or replace function k_skyband_last(dataset text, k integer) 
    returns setof PointRecord
as $$
declare
	counter integer;
	my_record PointRecord;
	ret_result PointRecord;
begin	
	for my_record in execute format('select * from %I', dataset)
	loop
		select count(*) into counter from has_domination(my_record.x, my_record.y, dataset);
		if (counter < k and counter >= k-1) then
			ret_result.x := my_record.x;
			ret_result.y := my_record.y;
			return next ret_result;
		end if;

	end loop;
end;
$$ language plpgsql;

drop function if exists skyband(text, integer) cascade;

-- This function calculates skyline in O(n^2)
create or replace function skyband(dataset text, k integer)  
    returns integer
as $$
--... SQL statements, possibly using other views/functions defined by you ...
declare
	counter integer := 0;
	tmp integer := 0;
	xarr integer[];
	tmpx integer[];
	yarr integer[];
	tmpy integer[];
	viewname varchar := dataset||'_skyband';
	i integer := 0;
begin	
	while k > 0
	loop
		-- by appending the array and create the view for the resulting array
		execute 'select count(*) from k_skyband_last($1,$2)' into tmp using dataset, k;
		execute 'select array(select x from k_skyband_last($1,$2))' into tmpx using dataset, k;
		execute 'select array(select y from k_skyband_last($1,$2))' into tmpy using dataset, k;
		counter := counter + tmp;
		execute format('select %L::integer[] || %L::integer[]', xarr, tmpx) into xarr;
		execute format('select %L::integer[] || %L::integer[]', yarr, tmpy) into yarr;
		k := k - 1;
	end loop;
	execute format('create or replace view %I'||'_skyband(x,y)'||' as select unnest(%L::integer[]), unnest(%L::integer[])', dataset, xarr, yarr);
	return counter;
	foreach i in array yarr
	loop
		i := i + 1;
	end loop;
	--return i;
end;
$$ language plpgsql;
