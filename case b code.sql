-- add a column which is counterparty type from customer to col_trans
drop table cust_2;
create table cust_2 as
select 
      *,
      case
          when jurisdiction= 'Canada' and industry = 'Financial' then 'Domesitc Banks'
          when jurisdiction = 'Canada' and industry <> 'Financial' then 'Other Domestic'
          else 'Foreign Cpty'
      end as cpty_type
from customer
;

-- add asset class type to the Sec table

create table sec_2 as
select *,
         case
         when industry = 'Sovereign' and security_type = 'Bond' then 'Level_1_Asset'
         when industry not in ('Insurance','Sovereign', 'Financial') and 
         Issuer_Credit_Rating like 'A%' and Issuer_Credit_Rating <> 'A-' then 'Level_2_Asset'
         else 'Level_3_Asset'
         end as 'Asset_Class'
from Sec;

-- join the table cust2 to the col_tran table (ignore product type ---cash)
drop table cust_join;
create table cust_join as 
select a.*,
       b.cpty_type
from col_trans a left join cust_2 b
on a.customer_id = b.customer_id
where product_type = 'Security';

-- join the table cust_join with sec_2 table
drop table asset_join;
create table asset_join as
select a.*,
       case
       when b.Asset_Class is null then c.Asset_Class
       else b.Asset_Class
       end as Asset_type
from cust_join a left join sec_2 b
on a.security_id = b.security_id
left join sec_2 c
on a.security_id = c.security_id_2;

--method 2 for join cust_join to the col_tran table


create table asset_join_1 as
select a.*,
      coalesce(b.Asset_Class, c.Asset_Class) as Asset_level
from cust_join a left join sec_2 b
on a.security_id = b.security_id
left join sec_2 c
on a.security_id = c.security_id_2;


--method 3

create table asset_join_2 as
select a.*,
       b.Asset_Class
from cust_join a left join 
sec_2 b
on a.security_id = b.security_id
or a.security_id = b.security_id_2;

--method 4 use sub_sequrey

create table asset_join_3 as
select a.*,
(select b.Asset_Class from sec_2 b
where b.security_id = a.security_id or b.security_id)
as asset_class
from cust_join a
;

-- get the direction and transpose the level of assets

create table final_report as
select cpty_type,
case
when post_direction = 'Deliv to Bank' then 'Collateral Received' 
     else 'Collateral Pledged'
end as Direction, -- case --> difine direction
margin_type,
sum(case when Asset_type = 'Level_1_Asset' then pv_cde else 0 end) as Level_1_Asset,
sum(case when Asset_type = 'Level_2_Asset' then pv_cde else 0 end) as Level_2_Asset,-- transpose the assets level
sum(case when Asset_type = 'Level_3_Asset' then pv_cde else 0 end) as Level_3_Asset   -- more like a sum up
from asset_join
group by cpty_type, direction, margin_type
order by cpty_type, direction, margin_type -- match up and sort for the report
;

-- use cross join to restructure the report

create table re_report as
select
a.cpty_type,
b.direction,
c.margin_type
from (select distinct cpty_type from final_report) a
cross join (select distinct direction from final_report) b
cross join (select distinct margin_type from final_report) c
order by  cpty_type, direction, margin_type;

-- add asset level to the table

create table real_report as
select
a.cpty_type,
a.direction,
a.margin_type,
coalesce(b.level_1_asset,0) as Level_1_asset,
coalesce(b.level_2_asset,0) as Level_2_asset,
coalesce(b.level_3_asset,0) as Level_3_asset
from re_report a left join final_report b
on a.cpty_type = b. cpty_type
and a.direction = b.direction
and a.margin_type = b.margin_type
;


