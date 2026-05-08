## Ryan Severns  [12:01 PM]

Hey @Devon - I have been reviewing reports in Looker and they aren't reconciling with the data that we have in HubSpot. I'd love to dig in with you and figure out what is causing the variance.

Some examples are below for you to review. Can you please grab a time for us to take a look together?

cc: @Dave Kart for visibility into the variances

### PQL Variance Analysis - comparing this dashboard in Looker vs. this dashboard in HubSpot on a YTD basis
- looker report: https://soundstripe.cloud.looker.com/dashboards/71?Lead+Date=this+year+to+second&Date+Trunc=month&Last+Channel+Non+Direct=&Deal+Grouping=enterprise+new+deal&Lead+Type=new+process%3A+pql
```---
- dashboard: marketing_pql_monitoring
  title: Marketing PQL Monitoring
  description: ''
  preferred_slug: K0nXUgoYZXnf7K1MDF7rT7
  layout: newspaper
  tabs:
  - name: ''
    label: ''
  elements:
  - title: PQLs
    name: PQLs
    model: General
    explore: dim_enterprise_leads
    type: single_value
    fields: [dim_enterprise_leads.leads]
    limit: 500
    column_limit: 50
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    listen:
      Date Trunc: dim_enterprise_leads.date_trunc
      Lead Date: dim_enterprise_leads.lead_date
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Lead Type: dim_enterprise_leads.lead_type
    row: 0
    col: 0
    width: 5
    height: 2
    tab_name: ''
  - title: PQLs - Quality Lead
    name: PQLs - Quality Lead
    model: General
    explore: dim_enterprise_leads
    type: single_value
    fields: [dim_enterprise_leads.leads]
    filters:
      stg_contacts_2.lead_status_grouped: enterprise customer,good lead,nurture state,sync
        customer
    limit: 500
    column_limit: 50
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    listen:
      Date Trunc: dim_enterprise_leads.date_trunc
      Lead Date: dim_enterprise_leads.lead_date
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Lead Type: dim_enterprise_leads.lead_type
    row: 0
    col: 5
    width: 5
    height: 2
    tab_name: ''
  - title: PQLs - Deals Won
    name: PQLs - Deals Won
    model: General
    explore: dim_enterprise_leads
    type: single_value
    fields: [dim_enterprise_deals.deals_closed_won]
    limit: 500
    column_limit: 50
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Date Trunc: dim_enterprise_leads.date_trunc
      Lead Date: dim_enterprise_leads.lead_date
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Deal Grouping: dim_enterprise_deals.deal_grouping
      Lead Type: dim_enterprise_leads.lead_type
    row: 0
    col: 15
    width: 5
    height: 2
    tab_name: ''
  - title: PQLs - Deals Created
    name: PQLs - Deals Created
    model: General
    explore: dim_enterprise_leads
    type: single_value
    fields: [dim_enterprise_deals.deals]
    limit: 500
    column_limit: 50
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Date Trunc: dim_enterprise_leads.date_trunc
      Lead Date: dim_enterprise_leads.lead_date
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Deal Grouping: dim_enterprise_deals.deal_grouping
      Lead Type: dim_enterprise_leads.lead_type
    row: 0
    col: 10
    width: 5
    height: 2
    tab_name: ''
  - title: PQLs by Last Channel Non Direct
    name: PQLs by Last Channel Non Direct
    model: General
    explore: dim_enterprise_leads
    type: looker_column
    fields: [dim_enterprise_leads.leads, dim_enterprise_leads.dynamic_lead_date, fct_sessions.last_channel_non_direct]
    pivots: [fct_sessions.last_channel_non_direct]
    sorts: [fct_sessions.last_channel_non_direct, dim_enterprise_leads.dynamic_lead_date]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: normal
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: true
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    listen:
      Date Trunc: dim_enterprise_leads.date_trunc
      Lead Date: dim_enterprise_leads.lead_date
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Lead Type: dim_enterprise_leads.lead_type
    row: 2
    col: 0
    width: 12
    height: 7
    tab_name: ''
  - title: PQLs - Deal Value
    name: PQLs - Deal Value
    model: General
    explore: dim_enterprise_leads
    type: single_value
    fields: [dim_enterprise_deals.value_deals_closed_won]
    limit: 500
    column_limit: 50
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Date Trunc: dim_enterprise_leads.date_trunc
      Lead Date: dim_enterprise_leads.lead_date
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Deal Grouping: dim_enterprise_deals.deal_grouping
      Lead Type: dim_enterprise_leads.lead_type
    row: 0
    col: 20
    width: 4
    height: 2
    tab_name: ''
  - title: PQLs Performance by Channel
    name: PQLs Performance by Channel
    model: General
    explore: dim_enterprise_leads
    type: looker_grid
    fields: [fct_sessions.last_channel_non_direct, dim_enterprise_leads.leads, dim_enterprise_leads.sales_accepted_leads,
      dim_enterprise_leads.sales_qualified_leads, dim_enterprise_deals.deals, dim_enterprise_deals.deals_closed_won,
      dim_enterprise_deals.value_deals_closed_won, dim_enterprise_deals.new_enterprise_deals,
      dim_enterprise_deals.new_enterprise_deals_closed_won, dim_enterprise_deals.new_enterprise_deals_closed_won_value]
    sorts: [dim_enterprise_leads.leads desc]
    limit: 500
    column_limit: 50
    show_view_names: false
    show_row_numbers: false
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    limit_displayed_rows: false
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: '12'
    rows_font_size: '12'
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    show_sql_query_menu_options: false
    show_totals: true
    show_row_totals: true
    truncate_header: false
    minimum_column_width: 75
    series_cell_visualizations:
      dim_enterprise_leads.leads:
        is_active: false
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    x_axis_zoom: true
    y_axis_zoom: true
    trellis: ''
    stacking: percent
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: true
    show_silhouette: false
    totals_color: "#808080"
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Date Trunc: dim_enterprise_leads.date_trunc
      Lead Date: dim_enterprise_leads.lead_date
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Lead Type: dim_enterprise_leads.lead_type
    row: 9
    col: 0
    width: 24
    height: 6
    tab_name: ''
  - title: PQLs by Source and State
    name: PQLs by Source and State
    model: General
    explore: dim_enterprise_leads
    type: looker_bar
    fields: [dim_enterprise_leads.leads, fct_sessions.last_channel_non_direct, dim_enterprise_leads.lead_status]
    pivots: [dim_enterprise_leads.lead_status]
    sorts: [dim_enterprise_leads.lead_status, fct_sessions.last_channel_non_direct]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: percent
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: true
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Date Trunc: dim_enterprise_leads.date_trunc
      Lead Date: dim_enterprise_leads.lead_date
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Lead Type: dim_enterprise_leads.lead_type
    row: 2
    col: 12
    width: 12
    height: 7
    tab_name: ''
  filters:
  - name: Date Trunc
    title: Date Trunc
    type: field_filter
    default_value: month
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: General
    explore: dim_enterprise_leads
    listens_to_filters: []
    field: dim_enterprise_leads.date_trunc
  - name: Lead Date
    title: Lead Date
    type: field_filter
    default_value: 30 day
    allow_multiple_values: true
    required: false
    ui_config:
      type: relative_timeframes
      display: inline
      options: []
    model: General
    explore: dim_enterprise_leads
    listens_to_filters: []
    field: dim_enterprise_leads.lead_date
  - name: Last Channel Non Direct
    title: Last Channel Non Direct
    type: field_filter
    default_value: ''
    allow_multiple_values: true
    required: false
    ui_config:
      type: tag_list
      display: popover
    model: General
    explore: dim_enterprise_leads
    listens_to_filters: []
    field: fct_sessions.last_channel_non_direct
  - name: Deal Grouping
    title: Deal Grouping
    type: field_filter
    default_value: enterprise new deal
    allow_multiple_values: true
    required: false
    ui_config:
      type: checkboxes
      display: popover
    model: General
    explore: dim_enterprise_leads
    listens_to_filters: []
    field: dim_enterprise_deals.deal_grouping
  - name: Lead Type
    title: Lead Type
    type: field_filter
    default_value: 'new process: pql'
    allow_multiple_values: true
    required: false
    ui_config:
      type: tag_list
      display: popover
    model: General
    explore: dim_enterprise_leads
    listens_to_filters: []
    field: dim_enterprise_leads.lead_type
```
- hubspot report: https://app.hubspot.com/reports-dashboard/4192879/view/18806221
```Include data if it matches:
ALL of the filters below
1
Create date is after 12/31/2024 (CST) 
Contacts
and
2
Is PQL is equal to 1 
Contacts
and
3
Contacts
is not member of segment
[MASTER] ALL Contacts w/ Free Email Domain List
and
4
Became a PQL Lead Status is known 
Contacts
```
4,171 PQLs on the Looker Dashboard vs. 3,523 for HubSpot
27 PQL deals created in Looker vs. 13 in HubSpot



### MQL Variance Analysis - comparing this dashboard in Looker vs. this dashboard in HubSpot on a YTD basis
- looker report: https://soundstripe.cloud.looker.com/dashboards/60?Submission+Ts+Year=after+2026%2F01%2F01&Last+Channel+Non+Direct=&Email+Category=
```---
- dashboard: marketing_mql_monitoring
  title: Marketing MQL Monitoring
  preferred_viewer: dashboards-next
  crossfilter_enabled: true
  description: ''
  preferred_slug: YMB0HAJCm3oj3X3HnsmsWs
  layout: newspaper
  tabs:
  - name: ''
    label: ''
  elements:
  - title: MQLs Trended
    name: MQLs Trended
    model: General
    explore: dim_mql_mapping
    type: looker_column
    fields: [dim_mql_mapping.submission_ts_month, dim_mql_mapping.mqls, dim_mql_mapping.match_reason_ordered]
    pivots: [dim_mql_mapping.match_reason_ordered]
    fill_fields: [dim_mql_mapping.submission_ts_month]
    filters:
      dim_mql_mapping.submission_ts_year: after 2024/01/01
    sorts: [dim_mql_mapping.match_reason_ordered, dim_mql_mapping.submission_ts_month
        desc]
    limit: 500
    column_limit: 50
    total: true
    dynamic_fields:
    - _kind_hint: measure
      _type_hint: number
      args:
      - dim_mql_mapping.mqls
      based_on: dim_mql_mapping.mqls
      calculation_type: percent_of_row
      category: table_calculation
      label: Percent of row
      source_field: dim_mql_mapping.mqls
      table_calculation: percent_of_row
      value_format:
      value_format_name: percent_0
      is_disabled: true
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: normal
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: true
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    hidden_pivots: {}
    show_row_numbers: true
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    listen:
      Submission Ts Year: dim_mql_mapping.submission_ts_year
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Email Category: stg_contacts_2.email_category
    row: 2
    col: 0
    width: 19
    height: 7
    tab_name: ''
  - title: MQL by Last Channel Non Direct
    name: MQL by Last Channel Non Direct
    model: General
    explore: dim_mql_mapping
    type: looker_column
    fields: [dim_mql_mapping.mqls, fct_sessions.last_channel_non_direct, stg_contacts_2.lead_status]
    pivots: [stg_contacts_2.lead_status]
    filters:
      dim_mql_mapping.submission_ts_year: after 2024/01/01
    sorts: [stg_contacts_2.lead_status, fct_sessions.last_channel_non_direct, dim_mql_mapping.mqls
        desc 0]
    limit: 500
    column_limit: 50
    dynamic_fields:
    - _kind_hint: measure
      _type_hint: number
      args:
      - dim_mql_mapping.mqls
      based_on: dim_mql_mapping.mqls
      calculation_type: percent_of_row
      category: table_calculation
      label: Percent of row
      source_field: dim_mql_mapping.mqls
      table_calculation: percent_of_row
      value_format:
      value_format_name: percent_0
      is_disabled: true
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: normal
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: true
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    hidden_pivots: {}
    show_row_numbers: true
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    listen:
      Submission Ts Year: dim_mql_mapping.submission_ts_year
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Email Category: stg_contacts_2.email_category
    row: 9
    col: 0
    width: 12
    height: 8
    tab_name: ''
  - title: MQLs by Mixpanel Match
    name: MQLs by Mixpanel Match
    model: General
    explore: dim_mql_mapping
    type: looker_pie
    fields: [dim_mql_mapping.mqls, dim_mql_mapping.match_reason_ordered]
    filters:
      dim_mql_mapping.submission_ts_year: after 2024/01/01
    sorts: [dim_mql_mapping.match_reason_ordered]
    limit: 500
    column_limit: 50
    total: true
    dynamic_fields:
    - _kind_hint: measure
      _type_hint: number
      args:
      - dim_mql_mapping.mqls
      based_on: dim_mql_mapping.mqls
      calculation_type: percent_of_row
      category: table_calculation
      label: Percent of row
      source_field: dim_mql_mapping.mqls
      table_calculation: percent_of_row
      value_format:
      value_format_name: percent_0
      is_disabled: true
    value_labels: legend
    label_type: labPer
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    x_axis_zoom: true
    y_axis_zoom: true
    trellis: ''
    stacking: normal
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: true
    show_silhouette: false
    totals_color: "#808080"
    hidden_pivots: {}
    show_row_numbers: true
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    listen:
      Submission Ts Year: dim_mql_mapping.submission_ts_year
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Email Category: stg_contacts_2.email_category
    row: 2
    col: 19
    width: 5
    height: 7
    tab_name: ''
  - title: MQL by Source and State
    name: MQL by Source and State
    model: General
    explore: dim_mql_mapping
    type: looker_bar
    fields: [dim_mql_mapping.mqls, dim_enterprise_leads.lead_status, fct_sessions.last_channel_non_direct]
    pivots: [dim_enterprise_leads.lead_status]
    filters:
      dim_mql_mapping.submission_ts_year: after 2024/01/01
    sorts: [dim_enterprise_leads.lead_status, dim_mql_mapping.mqls desc 0]
    limit: 500
    column_limit: 50
    dynamic_fields:
    - _kind_hint: measure
      _type_hint: number
      args:
      - dim_mql_mapping.mqls
      based_on: dim_mql_mapping.mqls
      calculation_type: percent_of_row
      category: table_calculation
      label: Percent of row
      source_field: dim_mql_mapping.mqls
      table_calculation: percent_of_row
      value_format:
      value_format_name: percent_0
      is_disabled: true
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: percent
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: true
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    hidden_pivots: {}
    show_row_numbers: true
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    listen:
      Submission Ts Year: dim_mql_mapping.submission_ts_year
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Email Category: stg_contacts_2.email_category
    row: 9
    col: 12
    width: 12
    height: 8
    tab_name: ''
  - title: MQLs - Quality Lead
    name: MQLs - Quality Lead
    model: General
    explore: dim_mql_mapping
    type: single_value
    fields: [dim_mql_mapping.mqls]
    filters:
      dim_mql_mapping.submission_ts_year: after 2024/01/01
      stg_contacts_2.lead_status_grouped: enterprise customer,good lead,nurture state,sync
        customer
    limit: 500
    column_limit: 50
    total: true
    dynamic_fields:
    - _kind_hint: measure
      _type_hint: number
      args:
      - dim_mql_mapping.mqls
      based_on: dim_mql_mapping.mqls
      calculation_type: percent_of_row
      category: table_calculation
      label: Percent of row
      source_field: dim_mql_mapping.mqls
      table_calculation: percent_of_row
      value_format:
      value_format_name: percent_0
      is_disabled: true
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: normal
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: true
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    hidden_pivots: {}
    show_row_numbers: true
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    defaults_version: 1
    listen:
      Submission Ts Year: dim_mql_mapping.submission_ts_year
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Email Category: stg_contacts_2.email_category
    row: 0
    col: 8
    width: 4
    height: 2
    tab_name: ''
  - title: MQLs - Deals Created
    name: MQLs - Deals Created
    model: General
    explore: dim_mql_mapping
    type: single_value
    fields: [dim_enterprise_deals.deals]
    filters:
      dim_mql_mapping.submission_ts_year: after 2024/01/01
    limit: 500
    column_limit: 50
    total: true
    dynamic_fields:
    - _kind_hint: measure
      _type_hint: number
      args:
      - dim_mql_mapping.mqls
      based_on: dim_mql_mapping.mqls
      calculation_type: percent_of_row
      category: table_calculation
      label: Percent of row
      source_field: dim_mql_mapping.mqls
      table_calculation: percent_of_row
      value_format:
      value_format_name: percent_0
      is_disabled: true
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: normal
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: true
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    hidden_pivots: {}
    show_row_numbers: true
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    defaults_version: 1
    listen:
      Submission Ts Year: dim_mql_mapping.submission_ts_year
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Email Category: stg_contacts_2.email_category
    row: 0
    col: 12
    width: 4
    height: 2
    tab_name: ''
  - title: MQLs Matched
    name: MQLs Matched
    model: General
    explore: dim_mql_mapping
    type: single_value
    fields: [dim_mql_mapping.mqls]
    filters:
      dim_mql_mapping.submission_ts_year: after 2024/01/01
      dim_mql_mapping.match_reason: "-no match"
    limit: 500
    column_limit: 50
    total: true
    dynamic_fields:
    - _kind_hint: measure
      _type_hint: number
      args:
      - dim_mql_mapping.mqls
      based_on: dim_mql_mapping.mqls
      calculation_type: percent_of_row
      category: table_calculation
      label: Percent of row
      source_field: dim_mql_mapping.mqls
      table_calculation: percent_of_row
      value_format:
      value_format_name: percent_0
      is_disabled: true
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: normal
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: true
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    hidden_pivots: {}
    show_row_numbers: true
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    defaults_version: 1
    listen:
      Submission Ts Year: dim_mql_mapping.submission_ts_year
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Email Category: stg_contacts_2.email_category
    row: 0
    col: 4
    width: 4
    height: 2
    tab_name: ''
  - title: MQLs - Deal Value
    name: MQLs - Deal Value
    model: General
    explore: dim_mql_mapping
    type: single_value
    fields: [dim_enterprise_deals.total_bookings]
    filters:
      dim_mql_mapping.submission_ts_year: after 2024/01/01
      dim_enterprise_deals.stage_category: won
    limit: 500
    column_limit: 50
    total: true
    dynamic_fields:
    - _kind_hint: measure
      _type_hint: number
      args:
      - dim_mql_mapping.mqls
      based_on: dim_mql_mapping.mqls
      calculation_type: percent_of_row
      category: table_calculation
      label: Percent of row
      source_field: dim_mql_mapping.mqls
      table_calculation: percent_of_row
      value_format:
      value_format_name: percent_0
      is_disabled: true
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: normal
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: true
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    hidden_pivots: {}
    show_row_numbers: true
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    defaults_version: 1
    listen:
      Submission Ts Year: dim_mql_mapping.submission_ts_year
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Email Category: stg_contacts_2.email_category
    row: 0
    col: 20
    width: 4
    height: 2
    tab_name: ''
  - title: MQLs (Hubspot)
    name: MQLs (Hubspot)
    model: General
    explore: dim_mql_mapping
    type: single_value
    fields: [dim_mql_mapping.mqls]
    filters:
      dim_mql_mapping.submission_ts_year: after 2024/01/01
    limit: 500
    column_limit: 50
    total: true
    dynamic_fields:
    - _kind_hint: measure
      _type_hint: number
      args:
      - dim_mql_mapping.mqls
      based_on: dim_mql_mapping.mqls
      calculation_type: percent_of_row
      category: table_calculation
      label: Percent of row
      source_field: dim_mql_mapping.mqls
      table_calculation: percent_of_row
      value_format:
      value_format_name: percent_0
      is_disabled: true
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: normal
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: true
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    hidden_pivots: {}
    show_row_numbers: true
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    defaults_version: 1
    listen:
      Submission Ts Year: dim_mql_mapping.submission_ts_year
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Email Category: stg_contacts_2.email_category
    row: 0
    col: 0
    width: 4
    height: 2
    tab_name: ''
  - title: MQLs - Deals Won
    name: MQLs - Deals Won
    model: General
    explore: dim_mql_mapping
    type: single_value
    fields: [dim_enterprise_deals.deals_closed_won]
    filters:
      dim_mql_mapping.submission_ts_year: after 2024/01/01
    limit: 500
    column_limit: 50
    total: true
    dynamic_fields:
    - _kind_hint: measure
      _type_hint: number
      args:
      - dim_mql_mapping.mqls
      based_on: dim_mql_mapping.mqls
      calculation_type: percent_of_row
      category: table_calculation
      label: Percent of row
      source_field: dim_mql_mapping.mqls
      table_calculation: percent_of_row
      value_format:
      value_format_name: percent_0
      is_disabled: true
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: normal
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: true
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    hidden_pivots: {}
    show_row_numbers: true
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    defaults_version: 1
    listen:
      Submission Ts Year: dim_mql_mapping.submission_ts_year
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Email Category: stg_contacts_2.email_category
    row: 0
    col: 16
    width: 4
    height: 2
    tab_name: ''
  - title: MQL Performance by Channel
    name: MQL Performance by Channel
    model: General
    explore: dim_mql_mapping
    type: looker_grid
    fields: [dim_mql_mapping.mqls, fct_sessions.last_channel_non_direct, dim_enterprise_leads.sales_accepted_leads,
      dim_enterprise_leads.sales_qualified_leads, dim_enterprise_deals.deals_in_progress,
      dim_enterprise_deals.deals_closed_won, dim_enterprise_deals.value_deals_closed_won]
    filters:
      dim_mql_mapping.submission_ts_year: after 2024/01/01
    sorts: [dim_mql_mapping.mqls desc]
    limit: 500
    column_limit: 50
    dynamic_fields:
    - _kind_hint: measure
      _type_hint: number
      args:
      - dim_mql_mapping.mqls
      based_on: dim_mql_mapping.mqls
      calculation_type: percent_of_row
      category: table_calculation
      label: Percent of row
      source_field: dim_mql_mapping.mqls
      table_calculation: percent_of_row
      value_format:
      value_format_name: percent_0
      is_disabled: true
    show_view_names: false
    show_row_numbers: false
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: editable
    limit_displayed_rows: false
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: '12'
    rows_font_size: '12'
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    show_sql_query_menu_options: false
    show_totals: true
    show_row_totals: true
    truncate_header: false
    minimum_column_width: 75
    series_cell_visualizations:
      dim_mql_mapping.mqls:
        is_active: false
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: normal
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: true
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    hidden_pivots: {}
    truncate_column_names: false
    defaults_version: 1
    listen:
      Submission Ts Year: dim_mql_mapping.submission_ts_year
      Last Channel Non Direct: fct_sessions.last_channel_non_direct
      Email Category: stg_contacts_2.email_category
    row: 17
    col: 0
    width: 24
    height: 8
    tab_name: ''
  filters:
  - name: Submission Ts Year
    title: Submission Ts Year
    type: field_filter
    default_value: after 2024/01/01
    allow_multiple_values: true
    required: false
    ui_config:
      type: advanced
      display: popover
    model: General
    explore: dim_mql_mapping
    listens_to_filters: []
    field: dim_mql_mapping.submission_ts_year
  - name: Last Channel Non Direct
    title: Last Channel Non Direct
    type: field_filter
    default_value: ''
    allow_multiple_values: true
    required: false
    ui_config:
      type: button_group
      display: popover
    model: General
    explore: dim_mql_mapping
    listens_to_filters: []
    field: fct_sessions.last_channel_non_direct
  - name: Email Category
    title: Email Category
    type: field_filter
    default_value: ''
    allow_multiple_values: true
    required: false
    ui_config:
      type: button_group
      display: popover
    model: General
    explore: dim_mql_mapping
    listens_to_filters: []
    field: stg_contacts_2.email_category
```
- hubspot report: https://app.hubspot.com/reports-dashboard/4192879/view/19857810?dbFrequency=QUARTER
```Include data if it matches:

ALL of the filters below
1
Contacts
is not member of segment

[MASTER] ALL Contacts w/ Free Email Domain List

and
2
Is MQL is equal to 1 
Contacts

and
3
Date First Became MQL is after 12/31/2024 (CST) 
Contacts
```
and
```Include data if it matches:

ALL of the filters below
1
Is Converted to Deal is equal to 1 
Contacts

and
2
Contacts
is not member of segment

[MASTER] ALL Contacts w/ Free Email Domain List

and
3
Date First Became MQL is after 12/31/2024 (CST) 
Contacts
```

758 MQLs in Looker vs. 470 in HubSpot
365 MQL deals in Looker vs. 337 in HubSpot


### Enterprise Pipeline - comparing this dashboard in Looker vs. this dashboard in HubSpot
- looker report: https://soundstripe.cloud.looker.com/dashboards/54?Event%20Month=2025%2F10%2F01%20to%202026%2F12%2F31&Lead%20Type=all
```---
- dashboard: enterprise_kpis
  title: Enterprise KPIs
  preferred_viewer: dashboards-next
  description: ''
  preferred_slug: 7uaSyiKisOaBzQ5a1ckLA1
  layout: newspaper
  tabs:
  - name: ''
    label: ''
  elements:
  - title: Leads
    name: Leads
    model: General
    explore: fct_kpis_enterprise
    type: looker_column
    fields: [fct_kpis_enterprise.event_month, fct_kpis_enterprise.dynamic_leads, dim_monthly_forecast.dynamic_leads]
    sorts: [fct_kpis_enterprise.event_month]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: normal
    limit_displayed_rows: false
    legend_position: center
    point_style: circle
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    series_types:
      dim_monthly_forecast.dynamic_leads: scatter
    series_colors:
      dim_monthly_forecast.enterprise_mqls: "#3E4451"
      dim_monthly_forecast.dynamic_leads: "#3E4451"
    series_labels:
      dim_monthly_forecast.enterprise_mqls: Budget
    series_point_styles:
      dim_monthly_forecast.dynamic_leads: triangle
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Event Month: fct_kpis_enterprise.event_month
      Lead Type: dim_monthly_forecast.lead_type
    row: 2
    col: 0
    width: 24
    height: 7
    tab_name: ''
  - title: Closed Won Deal ARR
    name: Closed Won Deal ARR
    model: General
    explore: fct_kpis_enterprise
    type: looker_column
    fields: [fct_kpis_enterprise.event_month, fct_kpis_enterprise.dynamic_closed_won_arr,
      dim_monthly_forecast.dynamic_bookings]
    sorts: [fct_kpis_enterprise.event_month]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: circle
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    series_types:
      dim_monthly_forecast.dynamic_bookings: scatter
    series_colors:
      dim_monthly_forecast.forecast_enterprise_bookings: "#3E4451"
      dim_monthly_forecast.dynamic_bookings: "#3E4451"
    series_point_styles:
      dim_monthly_forecast.dynamic_bookings: triangle
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Event Month: fct_kpis_enterprise.event_month
      Lead Type: dim_monthly_forecast.lead_type
    row: 48
    col: 0
    width: 12
    height: 7
    tab_name: ''
  - title: Closed Won Deal Avg ARR
    name: Closed Won Deal Avg ARR
    model: General
    explore: fct_kpis_enterprise
    type: looker_column
    fields: [fct_kpis_enterprise.event_month, fct_kpis_enterprise.dynamic_closed_won_avg_arr]
    sorts: [fct_kpis_enterprise.event_month]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Event Month: fct_kpis_enterprise.event_month
      Lead Type: dim_monthly_forecast.lead_type
    row: 48
    col: 12
    width: 12
    height: 7
    tab_name: ''
  - title: Renewals Lost
    name: Renewals Lost
    model: General
    explore: fct_kpis_enterprise
    type: looker_column
    fields: [fct_kpis_enterprise.event_month, fct_kpis_enterprise.renewal_deals_lost]
    sorts: [fct_kpis_enterprise.event_month]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Event Month: fct_kpis_enterprise.event_month
      Lead Type: dim_monthly_forecast.lead_type
    row: 57
    col: 12
    width: 12
    height: 7
    tab_name: ''
  - title: Renewals Won
    name: Renewals Won
    model: General
    explore: fct_kpis_enterprise
    type: looker_column
    fields: [fct_kpis_enterprise.event_month, fct_kpis_enterprise.renewal_deals_won]
    sorts: [fct_kpis_enterprise.event_month]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Event Month: fct_kpis_enterprise.event_month
      Lead Type: dim_monthly_forecast.lead_type
    row: 57
    col: 0
    width: 12
    height: 7
    tab_name: ''
  - title: Deals in Pipeline - Stage 2 through 5
    name: Deals in Pipeline - Stage 2 through 5
    model: General
    explore: fct_kpis_enterprise
    type: looker_column
    fields: [fct_kpis_enterprise.event_month, fct_kpis_enterprise.dynamic_pipeline_deals]
    sorts: [fct_kpis_enterprise.event_month]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Event Month: fct_kpis_enterprise.event_month
      Lead Type: dim_monthly_forecast.lead_type
    row: 32
    col: 0
    width: 12
    height: 7
    tab_name: ''
  - title: Deals in Pipeline ARR - Stage 2 through 5
    name: Deals in Pipeline ARR - Stage 2 through 5
    model: General
    explore: fct_kpis_enterprise
    type: looker_column
    fields: [fct_kpis_enterprise.event_month, fct_kpis_enterprise.dynamic_pipeline_amount]
    sorts: [fct_kpis_enterprise.event_month]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: circle
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    label_value_format: "$#,##0"
    series_colors:
      dim_monthly_forecast.forecast_enterprise_deals_in_stage_2_to_5: "#3E4451"
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Event Month: fct_kpis_enterprise.event_month
      Lead Type: dim_monthly_forecast.lead_type
    row: 32
    col: 12
    width: 12
    height: 7
    tab_name: ''
  - name: ''
    type: text
    title_text: ''
    subtitle_text: ''
    body_text: '[{"type":"h1","children":[{"text":"Renewals ","bold":true}],"align":"center"},{"type":"h3","align":"center","id":"v7ofg","children":[{"bold":true,"text":"(not
      filtered by the lead type selection)","color":"hsl(0, 100%, 50%)"}]}]'
    rich_content_json: '{"format":"slate"}'
    row: 55
    col: 0
    width: 24
    height: 2
    tab_name: ''
  - name: " (Copy 2)"
    type: text
    title_text: " (Copy 2)"
    subtitle_text: ''
    body_text: '[{"type":"h1","children":[{"text":"Deals","bold":true}],"align":"center"}]'
    rich_content_json: '{"format":"slate"}'
    row: 9
    col: 0
    width: 24
    height: 2
    tab_name: ''
  - name: " (Copy)"
    type: text
    title_text: " (Copy)"
    subtitle_text: ''
    body_text: '[{"type":"h1","children":[{"text":"Deals Won","bold":true}],"align":"center"}]'
    rich_content_json: '{"format":"slate"}'
    row: 39
    col: 0
    width: 24
    height: 2
    tab_name: ''
  - name: " (Copy 3)"
    type: text
    title_text: " (Copy 3)"
    subtitle_text: ''
    body_text: '[{"type":"h1","children":[{"text":"Leads","bold":true}],"align":"center"}]'
    rich_content_json: '{"format":"slate"}'
    row: 0
    col: 0
    width: 24
    height: 2
    tab_name: ''
  - title: New Deals Created - Stage 1
    name: New Deals Created - Stage 1
    model: General
    explore: fct_kpis_enterprise
    type: looker_column
    fields: [fct_kpis_enterprise.event_month, fct_kpis_enterprise.dynamic_deals_created]
    sorts: [fct_kpis_enterprise.event_month]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: circle
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    series_colors:
      dim_monthly_forecast.enterprise_mqls: "#3E4451"
      dim_monthly_forecast.dynamic_leads: "#3E4451"
    series_labels:
      dim_monthly_forecast.enterprise_mqls: Budget
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Event Month: fct_kpis_enterprise.event_month
      Lead Type: dim_monthly_forecast.lead_type
    row: 11
    col: 12
    width: 12
    height: 7
    tab_name: ''
  - title: 'Deals in Demo - Stage 2 '
    name: 'Deals in Demo - Stage 2 '
    model: General
    explore: fct_kpis_enterprise
    type: looker_column
    fields: [fct_kpis_enterprise.event_month, fct_kpis_enterprise.dynamic_demo_stage,
      dim_monthly_forecast.dynamic_demos]
    sorts: [fct_kpis_enterprise.event_month]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: circle
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    series_types:
      dim_monthly_forecast.dynamic_demos: scatter
    series_colors:
      dim_monthly_forecast.forecast_new_demos: "#3E4451"
      dim_monthly_forecast.dynamic_demos: "#3E4451"
    series_point_styles:
      dim_monthly_forecast.dynamic_demos: triangle
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Event Month: fct_kpis_enterprise.event_month
      Lead Type: dim_monthly_forecast.lead_type
    row: 25
    col: 0
    width: 12
    height: 7
    tab_name: ''
  - title: Deals Won
    name: Deals Won
    model: General
    explore: fct_kpis_enterprise
    type: looker_column
    fields: [fct_kpis_enterprise.event_month, fct_kpis_enterprise.dynamic_closed_won_deals]
    sorts: [fct_kpis_enterprise.event_month]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: circle
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    series_colors:
      dim_monthly_forecast.forecast_new_demos: "#3E4451"
      dim_monthly_forecast.dynamic_demos: "#3E4451"
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Event Month: fct_kpis_enterprise.event_month
      Lead Type: dim_monthly_forecast.lead_type
    row: 41
    col: 0
    width: 12
    height: 7
    tab_name: ''
  - title: Deals in Demo - Stage 2 ARR
    name: Deals in Demo - Stage 2 ARR
    model: General
    explore: fct_kpis_enterprise
    type: looker_column
    fields: [fct_kpis_enterprise.event_month, fct_kpis_enterprise.dynamic_demo_stage_deal_value]
    sorts: [fct_kpis_enterprise.event_month]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: circle
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    series_colors:
      dim_monthly_forecast.enterprise_mqls: "#3E4451"
      dim_monthly_forecast.dynamic_leads: "#3E4451"
    series_labels:
      dim_monthly_forecast.enterprise_mqls: Budget
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Event Month: fct_kpis_enterprise.event_month
      Lead Type: dim_monthly_forecast.lead_type
    row: 25
    col: 12
    width: 12
    height: 7
    tab_name: ''
  - title: Avg Days to Deals Won
    name: Avg Days to Deals Won
    model: General
    explore: fct_kpis_enterprise
    type: looker_column
    fields: [fct_kpis_enterprise.event_month, fct_kpis_enterprise.dynamic_avg_days_to_close]
    sorts: [fct_kpis_enterprise.event_month]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: circle
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    series_colors:
      dim_monthly_forecast.forecast_new_demos: "#3E4451"
      dim_monthly_forecast.dynamic_demos: "#3E4451"
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Event Month: fct_kpis_enterprise.event_month
      Lead Type: dim_monthly_forecast.lead_type
    row: 41
    col: 12
    width: 12
    height: 7
    tab_name: ''
  - title: New Deals per Lead
    name: New Deals per Lead
    model: General
    explore: fct_kpis_enterprise
    type: looker_column
    fields: [fct_kpis_enterprise.event_month, fct_kpis_enterprise.dynamic_lead_to_deal_create,
      dim_monthly_forecast.dynamic_demo_perc_of_leads]
    sorts: [fct_kpis_enterprise.event_month]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: circle
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    series_types:
      dim_monthly_forecast.dynamic_demo_perc_of_leads: scatter
    series_colors:
      dim_monthly_forecast.enterprise_mqls: "#3E4451"
      dim_monthly_forecast.dynamic_leads: "#3E4451"
      dim_monthly_forecast.dynamic_demo_perc_of_leads: "#3E4451"
    series_labels:
      dim_monthly_forecast.enterprise_mqls: Budget
    series_point_styles:
      dim_monthly_forecast.dynamic_demo_perc_of_leads: triangle
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Event Month: fct_kpis_enterprise.event_month
      Lead Type: dim_monthly_forecast.lead_type
    row: 11
    col: 0
    width: 12
    height: 7
    tab_name: ''
  - title: Demos per Lead
    name: Demos per Lead
    model: General
    explore: fct_kpis_enterprise
    type: looker_column
    fields: [fct_kpis_enterprise.event_month, fct_kpis_enterprise.dynamic_demo_per_lead,
      dim_monthly_forecast.dynamic_enterprise_demo_per_lead]
    sorts: [fct_kpis_enterprise.event_month]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: circle
    show_value_labels: true
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    series_types:
      dim_monthly_forecast.dynamic_enterprise_demo_per_lead: scatter
    series_colors:
      dim_monthly_forecast.forecast_new_demos: "#3E4451"
      dim_monthly_forecast.dynamic_demos: "#3E4451"
      dim_monthly_forecast.dynamic_enterprise_demo_per_lead: "#3E4451"
    series_point_styles:
      dim_monthly_forecast.dynamic_enterprise_demo_per_lead: triangle
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Event Month: fct_kpis_enterprise.event_month
      Lead Type: dim_monthly_forecast.lead_type
    row: 18
    col: 0
    width: 24
    height: 7
    tab_name: ''
  filters:
  - name: Event Month
    title: Event Month
    type: field_filter
    default_value: 2025/10/01 to 2026/12/31
    allow_multiple_values: true
    required: false
    ui_config:
      type: advanced
      display: popover
      options: []
    model: General
    explore: fct_kpis_enterprise
    listens_to_filters: []
    field: fct_kpis_enterprise.event_month
  - name: Lead Type
    title: Lead Type
    type: field_filter
    default_value: all
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: General
    explore: fct_kpis_enterprise
    listens_to_filters: []
    field: dim_monthly_forecast.lead_type
```
- hubspot report: https://app.hubspot.com/reports-dashboard/4192879/view/19860844
```Include data if it matches:

ALL of the filters below
1
Pipeline is any of Enterprise Pipeline 
Deals

and
2
Create date is after 12/31/2024 (CST) 
Deals
Inactive filters
Opportunity Source
Deals
click to apply filter
```


Deal creation variance - for example 155 deals in April from Looker vs. 131 in HubSpot


# Notes:
- 218412432524
  - the company associated with this contact shows an active enterprise account
- 218437852073
- 219735396375
- 219722147099
- 219695673679
