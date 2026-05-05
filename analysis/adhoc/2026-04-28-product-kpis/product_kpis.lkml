---
- dashboard: product_kpis
  title: Product KPIs
  description: ''
  preferred_slug: vuBQGtkq6MW8YTMr72QKu2
  layout: newspaper
  tabs:
  - name: ''
    label: ''
  elements:
  - title: Global Revenue per Session
    name: Global Revenue per Session
    model: General
    explore: fct_sessions
    type: looker_column
    fields: [fct_sessions.total_revenue_per_session, fct_sessions.dynamic_session_started]
    sorts: [fct_sessions.dynamic_session_started]
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
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    listen:
      Subscriber Category: fct_sessions.subscriber_category
      Date Trunc: fct_sessions.date_trunc
      Session Started At Date: fct_sessions.session_started_at_date
    row: 0
    col: 0
    width: 24
    height: 8
    tab_name: ''
  - title: Purchase Conversion Rate (per Session)
    name: Purchase Conversion Rate (per Session)
    model: General
    explore: fct_sessions
    type: looker_column
    fields: [fct_sessions.dynamic_session_started, fct_sessions.overall_conversion_rate]
    sorts: [fct_sessions.dynamic_session_started]
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
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Subscriber Category: fct_sessions.subscriber_category
      Date Trunc: fct_sessions.date_trunc
      Session Started At Date: fct_sessions.session_started_at_date
    row: 18
    col: 0
    width: 12
    height: 9
    tab_name: ''
  - title: 1 Yr LTV Per Transaction
    name: 1 Yr LTV Per Transaction
    model: General
    explore: fct_sessions
    type: looker_column
    fields: [fct_sessions.dynamic_session_started, fct_sessions.avg_transaction_and_sub_1yr_revenue]
    sorts: [fct_sessions.dynamic_session_started]
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
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Subscriber Category: fct_sessions.subscriber_category
      Date Trunc: fct_sessions.date_trunc
      Session Started At Date: fct_sessions.session_started_at_date
    row: 18
    col: 12
    width: 12
    height: 9
    tab_name: ''
  - title: Sign Ups per Session
    name: Sign Ups per Session
    model: General
    explore: fct_sessions
    type: looker_column
    fields: [fct_sessions.dynamic_session_started, fct_sessions.sign_ups_per_session]
    sorts: [fct_sessions.dynamic_session_started]
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
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Subscriber Category: fct_sessions.subscriber_category
      Date Trunc: fct_sessions.date_trunc
      Session Started At Date: fct_sessions.session_started_at_date
    row: 27
    col: 0
    width: 12
    height: 9
    tab_name: ''
  - name: ''
    type: text
    title_text: ''
    subtitle_text: ''
    body_text: '[{"type":"h1","children":[{"text":"Growth","bold":true}],"align":"center"}]'
    rich_content_json: '{"format":"slate"}'
    row: 16
    col: 0
    width: 24
    height: 2
    tab_name: ''
  - title: MQL Form Submissions per Session
    name: MQL Form Submissions per Session
    model: General
    explore: fct_sessions
    type: looker_column
    fields: [fct_sessions.dynamic_session_started, fct_sessions.mqls_per_session]
    sorts: [fct_sessions.dynamic_session_started]
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
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Subscriber Category: fct_sessions.subscriber_category
      Date Trunc: fct_sessions.date_trunc
      Session Started At Date: fct_sessions.session_started_at_date
    row: 27
    col: 12
    width: 12
    height: 9
    tab_name: ''
  - name: " (Copy)"
    type: text
    title_text: " (Copy)"
    subtitle_text: ''
    body_text: '[{"type":"h1","children":[{"text":"Retention","bold":true}],"align":"center"}]'
    rich_content_json: '{"format":"slate"}'
    row: 45
    col: 0
    width: 24
    height: 2
    tab_name: ''
  - title: "% of Subscribers Downloading Songs: 0 - 7 Days"
    name: "% of Subscribers Downloading Songs: 0 - 7 Days"
    model: General
    explore: fct_subscriber_activity_mixpanel
    type: looker_column
    fields: [fct_subscriber_activity_mixpanel.dynamic_sub_start_date, fct_subscriber_activity_mixpanel.song_downloading_subscriber_rate_param]
    filters:
      fct_subscriber_activity_mixpanel.days_since_sub: '7'
    sorts: [fct_subscriber_activity_mixpanel.dynamic_sub_start_date desc]
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
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Date Trunc: fct_subscriber_activity_mixpanel.date_trunc
      Session Started At Date: fct_subscriber_activity_mixpanel.dynamic_sub_start_date
    row: 47
    col: 0
    width: 12
    height: 7
    tab_name: ''
  - title: 'Song Downloads per Downloading Subscriber: 0 - 30 Days'
    name: 'Song Downloads per Downloading Subscriber: 0 - 30 Days'
    model: General
    explore: fct_subscriber_activity_mixpanel
    type: looker_column
    fields: [fct_subscriber_activity_mixpanel.dynamic_sub_start_date, fct_subscriber_activity_mixpanel.songs_downloaded_by_subscriber_param]
    filters:
      fct_subscriber_activity_mixpanel.days_since_sub: '30'
    sorts: [fct_subscriber_activity_mixpanel.dynamic_sub_start_date]
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
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Date Trunc: fct_subscriber_activity_mixpanel.date_trunc
      Session Started At Date: fct_subscriber_activity_mixpanel.dynamic_sub_start_date
    row: 47
    col: 12
    width: 12
    height: 7
    tab_name: ''
  - title: "% of Subscribers Downloading Songs: 30-60 Days"
    name: "% of Subscribers Downloading Songs: 30-60 Days"
    model: General
    explore: fct_subscriber_activity_mixpanel
    type: looker_column
    fields: [fct_subscriber_activity_mixpanel.dynamic_sub_start_date, fct_subscriber_activity_mixpanel.engaged_subscriber_rate_30_to_60]
    sorts: [fct_subscriber_activity_mixpanel.dynamic_sub_start_date desc]
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
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Date Trunc: fct_subscriber_activity_mixpanel.date_trunc
      Session Started At Date: fct_subscriber_activity_mixpanel.dynamic_sub_start_date
    row: 54
    col: 0
    width: 12
    height: 7
    tab_name: ''
  - title: 'Sessions per Engaged Subscriber: 30-60 Days'
    name: 'Sessions per Engaged Subscriber: 30-60 Days'
    model: General
    explore: fct_subscriber_activity_mixpanel
    type: looker_column
    fields: [fct_subscriber_activity_mixpanel.dynamic_sub_start_date, fct_subscriber_activity_mixpanel.sessions_per_engaged_subscriber_30_to_60]
    filters:
      fct_subscriber_activity_mixpanel.is_sub_30_to_60: 'Yes'
    sorts: [fct_subscriber_activity_mixpanel.dynamic_sub_start_date]
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
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Date Trunc: fct_subscriber_activity_mixpanel.date_trunc
      Session Started At Date: fct_subscriber_activity_mixpanel.dynamic_sub_start_date
    row: 54
    col: 12
    width: 12
    height: 7
    tab_name: ''
  - title: 'Subscription Expansion: 0-30 Days'
    name: 'Subscription Expansion: 0-30 Days'
    model: General
    explore: subscription_changes_retention
    type: looker_column
    fields: [subscription_changes_retention.dynamic_sub_date, subscription_changes_retention.expansion_rate]
    filters:
      subscription_changes_retention.prior_plan: personal,pro,pro-plus
    sorts: [subscription_changes_retention.dynamic_sub_date]
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
    show_null_points: true
    interpolation: linear
    defaults_version: 1
    listen:
      Date Trunc: subscription_changes_retention.date_trunc
      Session Started At Date: subscription_changes_retention.sub_start_date
    row: 61
    col: 0
    width: 12
    height: 7
    tab_name: ''
  - title: 'Avg 1Yr LTV Expansion Value: 0-30 Days'
    name: 'Avg 1Yr LTV Expansion Value: 0-30 Days'
    model: General
    explore: subscription_changes_retention
    type: looker_column
    fields: [subscription_changes_retention.dynamic_sub_date, subscription_changes_retention.avg_1_yr_value_of_expansion]
    sorts: [subscription_changes_retention.dynamic_sub_date]
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
    show_null_points: true
    interpolation: linear
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Date Trunc: subscription_changes_retention.date_trunc
      Session Started At Date: subscription_changes_retention.sub_start_date
    row: 61
    col: 12
    width: 12
    height: 7
    tab_name: ''
  - title: Engaged Visitor - Sign Up CVR
    name: Engaged Visitor - Sign Up CVR
    model: General
    explore: fct_sessions
    type: looker_column
    fields: [fct_sessions.visitor_sign_up_cvr, fct_sessions.dynamic_session_started]
    filters:
      fct_sessions.engaged_session_ind: 'Yes'
    sorts: [fct_sessions.dynamic_session_started desc]
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
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    hidden_pivots: {}
    listen:
      Subscriber Category: fct_sessions.subscriber_category
      Date Trunc: fct_sessions.date_trunc
      Session Started At Date: fct_sessions.session_started_at_date
    row: 36
    col: 0
    width: 12
    height: 9
    tab_name: ''
  - title: New Tile
    name: New Tile
    model: General
    explore: fct_sessions
    type: looker_column
    fields: [fct_sessions.total_revenue_per_session, fct_sessions.dynamic_session_started]
    filters:
      fct_sessions.date_trunc: week
      fct_sessions.session_started_at_date: 12 months
      fct_sessions.subscriber_category: ''
    sorts: [fct_sessions.dynamic_session_started]
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
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    listen:
      Date Trunc: fct_sessions.date_trunc
      Session Started At Date: fct_sessions.session_started_at_date
      Subscriber Category: fct_sessions.subscriber_category
    row: 68
    col: 0
    width: 8
    height: 6
    tab_name: ''
  - title: Global Revenue per Session - App Engaged Sessions (45 seconds or more)
    name: Global Revenue per Session - App Engaged Sessions (45 seconds or more)
    model: General
    explore: fct_sessions
    type: looker_column
    fields: [fct_sessions.total_revenue_per_session, fct_sessions.dynamic_session_started]
    filters:
      fct_sessions.has_app_view: Yes,No
      fct_sessions.engaged_session_ind: 'Yes'
    sorts: [fct_sessions.dynamic_session_started]
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
    truncate_column_names: false
    hide_totals: false
    hide_row_totals: false
    table_theme: editable
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    note_state: collapsed
    note_display: hover
    note_text: App Engaged Sessions are Sessions that have at least 1 page view associated
      with app.soundstripe.com and did not bounce. Bounce defined as sessions lasting
      <= 1 second with no conversion events
    listen:
      Subscriber Category: fct_sessions.subscriber_category
      Date Trunc: fct_sessions.date_trunc
      Session Started At Date: fct_sessions.session_started_at_date
    row: 8
    col: 0
    width: 24
    height: 8
    tab_name: ''
  filters:
  - name: Date Trunc
    title: Date Trunc
    type: field_filter
    default_value: week
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: General
    explore: fct_sessions
    listens_to_filters: []
    field: fct_sessions.date_trunc
  - name: Subscriber Category
    title: Subscriber Category
    type: field_filter
    default_value: ''
    allow_multiple_values: true
    required: false
    ui_config:
      type: tag_list
      display: popover
    model: General
    explore: fct_sessions
    listens_to_filters: []
    field: fct_sessions.subscriber_category
  - name: Session Started At Date
    title: Session Started At Date
    type: field_filter
    default_value: 12 month
    allow_multiple_values: true
    required: false
    ui_config:
      type: advanced
      display: popover
      options: []
    model: General
    explore: fct_sessions
    listens_to_filters: []
    field: fct_sessions.session_started_at_date
