# Beware, timestamps returned by the Datepicker React component are given in milliseconds!
class Search::ComplexDatationStrategy < Search::BaseStrategy
  permit_criteria :exact, :condition, :field_condition, :default, :child_choices_activated, :start => {}, :end => {}
  include Search::MultivaluedSearch

  def keywords_for_index(item)
    if field.selected_format(item) == 'datation_choice'
      choices = field.selected_choices(item)
      choices.flat_map { |choice| [choice.short_name, choice.long_name] }
    else
      date_for_keywords(item)
    end
  end

  def search(scope, criteria)
    field_condition = criteria[:condition]
    negate = criteria[:field_condition] == "exclude"

    scope = append_joins_on_choices(scope)

    if criteria[:default]
      if criteria[:child_choices_activated] == "true"
        choice = Choice.find(criteria[:default])
        str = "{#{(choice.childrens.pluck(:id) + [(criteria[:default] || criteria[:exact]).to_i]).flatten.map { |id| id }.join(', ')}}"
        scope = search_data_matching_more_complex_datation_choice(scope, str, negate)
      else
        scope = search_data_matching_one(scope, criteria[:default], negate)
      end
      return scope
    end

    return scope if criteria[:start].blank? && criteria[:end].blank?

    start_condition = criteria[:start].keys.first
    start_date_time = criteria[:start][start_condition]

    end_condition = criteria[:end].keys.first
    end_date_time = criteria[:end][end_condition] if end_date?(criteria)

    return scope if components_empty?(start_date_time) && components_empty?(end_date_time)

    scope = append_where_data_is_set(scope) unless negate
    scope = append_joins_on_choices(scope)

    search_interval_dates(
      scope, criteria, { start: start_date_time, end: end_date_time }, negate, field_condition
    )
  end

  private

  def date_for_keywords(item)
    return date_from_hash(raw_value(item)) if raw_value(item).is_a?(Hash)

    raw_value(item)
  end

  def date_from_hash(hash)
    hash.each_with_object([]) { |(_, v), array| array << v if v.present? }
  end

  def start_date?(criteria)
    condition = criteria[:start].keys.first
    criteria[:start].present? && criteria[:start][condition].present?
  end

  def end_date?(criteria)
    criteria[:end].present? && criteria[:end][criteria[:end].keys.first].present?
  end

  def search_interval_dates(scope, criteria, dates, negate, field_condition)
    interval_search(scope, dates[:start], dates[:end], field_condition, negate)
  end

  def inexact_search(scope, date_time, field_condition, negate)
    case field_condition
    when "exact"
    sql_operator = "="
      scope.where(
        "#{sql_select_table_name}.data->'#{field.uuid}'->>'selected_format' = 'date_time' AND
           #{date_time_to_interval(date_time, 'from')} #{sql_operator} #{make_interval(date_time)} AND
           #{date_time_to_interval(date_time, 'to')}  #{sql_operator} #{make_interval(date_time)}")
           .or(
             scope.where(
               "#{sql_select_table_name}.data->'#{field.uuid}'->>'selected_format' = 'datation_choice' AND
             #{choice_to_interval(date_time, 'from_date')} #{sql_operator} #{make_interval(date_time)} AND
             #{choice_to_interval(date_time, 'to_date')}  #{sql_operator} #{make_interval(date_time)}")
           )
    when "before"
      sql_operator = negate ? ">=" : "<="
      scope.where(
        "#{sql_select_table_name}.data->'#{field.uuid}'->>'selected_format' = 'date_time' AND
           ((#{date_time_to_interval(date_time, 'from')} #{sql_operator} #{make_interval(date_time)}) OR
           (#{date_time_to_interval(date_time, 'to')} #{sql_operator} #{make_interval(date_time)}) OR
           (#{where_date_is_not_set('from')}))"
      )
           .or(
             scope.where(
               "#{sql_select_table_name}.data->'#{field.uuid}'->>'selected_format' = 'datation_choice' AND
             ((#{choice_to_interval(date_time, 'from_date')} #{sql_operator} #{make_interval(date_time)}) OR
             (#{choice_to_interval(date_time, 'to_date')}  #{sql_operator} #{make_interval(date_time)}))")
           )
    when "after"
      sql_operator = negate ? "<=" : ">="
      scope.where(
        "#{sql_select_table_name}.data->'#{field.uuid}'->>'selected_format' = 'date_time' AND
           ((#{date_time_to_interval(date_time, 'from')} #{sql_operator} #{make_interval(date_time)}) OR
           (#{date_time_to_interval(date_time, 'to')} #{sql_operator} #{make_interval(date_time)}) OR
           (#{where_date_is_not_set('to')}))"
      )
           .or(
             scope.where(
               "#{sql_select_table_name}.data->'#{field.uuid}'->>'selected_format' = 'datation_choice' AND
             ((#{choice_to_interval(date_time, 'from_date')} #{sql_operator} #{make_interval(date_time)}) OR
             (#{choice_to_interval(date_time, 'to_date')}  #{sql_operator} #{make_interval(date_time)}))")
           )
    end
  end

  def interval_search(scope, start_date_time, end_date_time, field_condition, negate)

    return inexact_search(scope, start_date_time, field_condition, field_condition == "outside") if field_condition != 'outside' && field_condition != 'between'

    field_condition = field_condition == "between" ? "outside" : "between" if negate
    where_scope = ->(*q) { field_condition == "outside" ? scope.where.not(q) : scope.where(q) }

    where_scope.call(
      "
            (#{sql_select_table_name}.data->'#{field.uuid}'->>'selected_format' = 'date_time' AND
            ((NOT #{where_date_is_not_set('from')}) AND (NOT #{where_date_is_not_set('to')}) ) AND
            (CASE WHEN #{make_interval(start_date_time)} <= #{make_interval(end_date_time)}
             THEN
                (#{date_time_to_interval(start_date_time, 'from')}
                BETWEEN #{make_interval(start_date_time)}
                AND #{make_interval(end_date_time)})
                AND
                (#{date_time_to_interval(start_date_time, 'to')}
                BETWEEN #{make_interval(start_date_time)}
                AND #{make_interval(end_date_time)})
             ELSE
                (#{date_time_to_interval(start_date_time, 'from')}
                BETWEEN #{make_interval(end_date_time)}
                AND #{make_interval(start_date_time)})
                AND
                (#{date_time_to_interval(start_date_time, 'to')}
                BETWEEN #{make_interval(end_date_time)}
                AND #{make_interval(start_date_time)})
             END)) OR
             (#{sql_select_table_name}.data->'#{field.uuid}'->>'selected_format' = 'datation_choice' AND
             (CASE WHEN #{make_interval(start_date_time)} <= #{make_interval(end_date_time)}
             THEN
                (#{choice_to_interval(start_date_time, 'from_date')}
                BETWEEN #{make_interval(start_date_time)}
                AND #{make_interval(end_date_time)})
                AND
                (#{choice_to_interval(start_date_time, 'to_date')}
                BETWEEN #{make_interval(start_date_time)}
                AND #{make_interval(end_date_time)})
             ELSE
                (#{choice_to_interval(start_date_time, 'from_date')}
                BETWEEN #{make_interval(end_date_time)}
                AND #{make_interval(start_date_time)})
                AND
                (#{choice_to_interval(start_date_time, 'to_date')}
                BETWEEN #{make_interval(end_date_time)}
                AND #{make_interval(start_date_time)})
             END))"
    )
  end

  def date_time_to_interval(date_time, date_name)
    "
    ((CASE WHEN #{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'BC' = 'true'
    THEN -1
    ELSE 1
    END)  *
    make_interval(
        years := (CASE WHEN #{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'Y' IS NULL
           THEN '#{date_time_component(date_time, 'Y')}'
           ELSE LPAD(#{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'Y', 4, '0')
           END)::int,
        months := (CASE WHEN #{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'M' IS NULL
           THEN '#{date_time_component(date_time, 'M')}'
           ELSE LPAD(#{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'M', 2, '0')
           END)::int ,
        days := (CASE WHEN #{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'D' IS NULL
           THEN '#{date_time_component(date_time, 'D')}'
           ELSE LPAD(#{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'D', 2, '0')
           END)::int ,
        hours := (CASE WHEN #{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'h' IS NULL
           THEN '#{date_time_component(date_time, 'h')}'
           ELSE LPAD(#{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'h', 2, '0')
           END)::int ,
        mins := (CASE WHEN #{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'m' IS NULL
           THEN '#{date_time_component(date_time, 'm')}'
           ELSE LPAD(#{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'m', 2, '0')
           END)::int ,
        secs := (CASE WHEN #{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'s' IS NULL
           THEN '#{date_time_component(date_time, 's')}'
           ELSE LPAD(#{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'s', 2, '0')
           END)::int
    ))"
  end

  def choice_to_interval(date_time, date_name, can_invert=false)
    name = if can_invert
             date_name == 'from_date' ? 'to_date' : 'from_date'
           else
             date_name
           end
    "
    ((CASE WHEN #{sql_select_table_name}.data->'#{field.uuid}'->'selected_choices'->>'BC' = 'true'
    THEN -1
    ELSE 1
    END)  *
    (CASE WHEN #{sql_select_table_name}.data->'#{field.uuid}'->'selected_choices'->>'BC' = 'true'
    THEN
      make_interval(
        years := (CASE WHEN choices.#{name}::jsonb->>'Y' IS NULL
           THEN '#{date_time_component(date_time, 'Y')}'
           ELSE LPAD(choices.#{name}::jsonb->>'Y', 4, '0')
           END)::int ,
        months := (CASE WHEN choices.#{name}::jsonb->>'M' IS NULL
           THEN '#{date_time_component(date_time, 'M')}'
           ELSE LPAD(choices.#{name}::jsonb->>'M', 2, '0')
           END)::int ,
        days := (CASE WHEN choices.#{name}::jsonb->>'D' IS NULL
           THEN '#{date_time_component(date_time, 'D')}'
           ELSE LPAD(choices.#{name}::jsonb->>'D', 2, '0')
           END)::int ,
        hours := (CASE WHEN choices.#{name}::jsonb->>'h' IS NULL
           THEN '#{date_time_component(date_time, 'h')}'
           ELSE LPAD(choices.#{name}::jsonb->>'h', 2, '0')
           END)::int ,
        mins := (CASE WHEN choices.#{name}::jsonb->>'m' IS NULL
           THEN '#{date_time_component(date_time, 'm')}'
           ELSE LPAD(choices.#{name}::jsonb->>'m', 2, '0')
           END)::int ,
        secs := (CASE WHEN choices.#{name}::jsonb->>'s' IS NULL
           THEN '#{date_time_component(date_time, 's')}'
           ELSE LPAD(choices.#{name}::jsonb->>'s', 2, '0')
           END)::int
      )
    ELSE
      make_interval(
        years := (CASE WHEN choices.#{date_name}::jsonb->>'Y' IS NULL
           THEN '#{date_time_component(date_time, 'Y')}'
           ELSE LPAD(choices.#{date_name}::jsonb->>'Y', 4, '0')
           END)::int ,
        months := (CASE WHEN choices.#{date_name}::jsonb->>'M' IS NULL
           THEN '#{date_time_component(date_time, 'M')}'
           ELSE LPAD(choices.#{date_name}::jsonb->>'M', 2, '0')
           END)::int ,
        days := (CASE WHEN choices.#{date_name}::jsonb->>'D' IS NULL
           THEN '#{date_time_component(date_time, 'D')}'
           ELSE LPAD(choices.#{date_name}::jsonb->>'D', 2, '0')
           END)::int ,
        hours := (CASE WHEN choices.#{date_name}::jsonb->>'h' IS NULL
           THEN '#{date_time_component(date_time, 'h')}'
           ELSE LPAD(choices.#{date_name}::jsonb->>'h', 2, '0')
           END)::int ,
        mins := (CASE WHEN choices.#{date_name}::jsonb->>'m' IS NULL
           THEN '#{date_time_component(date_time, 'm')}'
           ELSE LPAD(choices.#{date_name}::jsonb->>'m', 2, '0')
           END)::int ,
        secs := (CASE WHEN choices.#{date_name}::jsonb->>'s' IS NULL
           THEN '#{date_time_component(date_time, 's')}'
           ELSE LPAD(choices.#{date_name}::jsonb->>'s', 2, '0')
           END)::int
      )
    END)
    )"
  end

  def make_interval(date_time)
    "(#{date_time['BC'] ? -1 : 1} * make_interval(
        years := ('#{date_time_component(date_time, 'Y')}')::int,
        months := ('#{date_time_component(date_time, 'M')}')::int ,
        days := ('#{date_time_component(date_time, 'D')}')::int ,
        hours := ('#{date_time_component(date_time, 'h')}')::int ,
        mins := ('#{date_time_component(date_time, 'm')}')::int ,
        secs := ('#{date_time_component(date_time, 's')}')::int
    ))"
  end

  def where_date_is_not_set(date_name)
    "((#{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'Y' IS NULL OR #{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'Y' = '') AND
      (#{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'M' IS NULL OR #{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'M' = '') AND
      (#{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'D' IS NULL OR #{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'D' = '') AND
      (#{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'h' IS NULL OR #{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'h' = '') AND
      (#{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'m' IS NULL OR #{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'m' = '') AND
      (#{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'s' IS NULL OR #{sql_select_table_name}.data->'#{field.uuid}'->'#{date_name}'->>'s' = ''))"
  end

  def append_where_data_is_set(scope)
    scope.where("#{sql_select_table_name}.data->'#{field.uuid}' IS NOT NULL")
  end

  def append_joins_on_choices(scope)
    query = Item.select("*, jsonb_array_elements(coalesce(items.data->'#{field.uuid}'->'selected_choices'->'value','[0]')) AS choice_id")
    scope.from("(#{query.to_sql}) items").joins("left join choices ON (choices.id = choice_id::INT)")
  end

  def date_time_component(date_time, key)
    return date_time[key].presence || "0000" if key == "Y"

    date_time[key].presence || "00"
  end

  def components_empty?(date_time)
    date_time.each { |_key, value| return false if value.present? }

    true
  end

  def data_field_expr
    "choice_id::text"
  end
end
