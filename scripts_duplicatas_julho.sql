-- Lista possíveis lançamentos duplicados em julho/2026
-- (mesma descrição + tipo + valor aparecendo mais de uma vez no mês,
-- considerando competência = mes_fatura || data, igual o app usa)

select
  descricao,
  tipo,
  valor,
  count(*)               as qtd,
  array_agg(id order by criado_em) as ids,
  array_agg(data order by criado_em) as datas,
  array_agg(criado_em order by criado_em) as criados_em
from fin_lancamentos
where coalesce(mes_fatura, data)::text like '2026-07%'
group by descricao, tipo, valor
having count(*) > 1
order by valor desc;

-- Se quiser ver TODOS os lançamentos de julho (sem agrupar), pra conferir manualmente:
-- select id, tipo, descricao, valor, data, mes_fatura, fixa, grupo_id, criado_em
-- from fin_lancamentos
-- where coalesce(mes_fatura, data)::text like '2026-07%'
-- order by descricao, criado_em;
