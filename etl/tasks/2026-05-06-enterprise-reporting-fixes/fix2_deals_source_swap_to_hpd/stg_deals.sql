/*
  ================================================================================
  stg_deals.sql — FIX 2: source swap to hubspot_platform_data.v2_daily.objects_deals
  ================================================================================
  Status:
      Replacing the Stitch-sourced model ({{ source('crm', 'deals') }} pointed at
      pc_stitch_db.hubspot_new.deals) with HubSpot's authoritative Operations Hub
      data share. HPD does not retain ghost records from soft-deleted/archived
      deals (the bug that caused variance 5: 24 ghost April 2026 deals, 345 lifetime).

      Direct table reference (hubspot_platform_data.v2_daily.objects_deals) is
      used here. If Fix 1 lands first with a dbt source for HPD, switch this
      to {{ source('hubspot_platform_data', 'objects_deals') }}.

  Schema mapping (Stitch → HPD):
      Stitch had 4 base columns + JSON `properties` blob + `associations` blob.
      HPD has 894 flat columns named PROPERTY_<X>. The mappings below cover the
      union of columns the original model emitted. Any column not listed below
      either:
        (a) doesn't have a 1:1 HPD equivalent (`properties_versions` — see notes.md)
        (b) is the same column with a renamed source (most cases)

  Open considerations (read fix2_deals_source_swap_to_hpd/notes.md before merging):
      - `properties_versions` is removed from the output. Downstream
        `stg_deals_event_log.sql` consumes this and will need to be rewritten
        to read from `hubspot_platform_data.v2_daily.object_properties_history`
        (filtered to objecttypeid='0-3').
      - The `stage_entered_ts` derivation used `properties:dealstage:timestamp`
        from Stitch's per-property timestamp metadata. HPD doesn't expose that
        on OBJECTS_DEALS; PROPERTY_HS_V2_DATE_ENTERED_CURRENT_STAGE is the
        closest equivalent for the CURRENT stage. If you need entered-date for
        ALL stage transitions, use OBJECT_PROPERTIES_HISTORY filtered to
        property_name='dealstage'.
      - Company association: original used `associations:associatedCompanyIds[0]`
        which grabbed the first array element (= primary in HubSpot's model).
        HPD's primary-association lookup uses
        `associations_deals_to_companies.ismainassociationdefinition = true`.
      - The test-deal exclusion list is preserved as-is. Any IDs no longer
        present in HPD are no-ops.
  ================================================================================
*/

with primary_company as
    (
        -- Replicates Stitch's `associations:associatedCompanyIds[0]` semantics
        -- by picking the main association per deal (or arbitrarily-first if no main flag).
        select
             deal_objectid                                                               as dealid
            ,company_objectid                                                            as companyid
        from hubspot_platform_data.v2_daily.associations_deals_to_companies
        qualify row_number() over (
            partition by deal_objectid
            order by ismainassociationdefinition desc nulls last, company_objectid
        ) = 1
    )

select
     d.objectid::string                                                                  as dealid
    ,d.property_pipeline                                                                 as pipelineid
    ,d.property_dealstage                                                                as stageid
    ,d.property_pipeline || '|' || d.property_dealstage                                  as pipeline_w_stage
    ,d.property_hs_v2_date_entered_current_stage                                         as stage_entered_ts
    ,pc.companyid
    ,d.property_dealname                                                                 as dealname
    ,d.property_dealtype                                                                 as dealtype
    ,try_to_boolean(d.property_does_this_agreement_automatically_renew__y_n__)           as autorenewal
    ,d.property_upsell_type                                                              as upsell_type
    ,d.property_hs_analytics_source                                                      as dealsource
    ,d.property_music_deal_source                                                        as music_deal_source
    ,d.property_createdate                                                               as createdate
    ,d.property_sourcecampaign                                                           as sourcecampaign
    ,d.property_amount                                                                   as amount
    ,d.property_closedate                                                                as closedate
    ,d.property_hs_closed_won_count                                                      as closed_won_flag
    -- Original used coalesce of two stage-entered timestamps; preserve both candidates.
    -- Note: HEAD references `hs_date_entered_1796976` (not present in HPD column list)
    -- and `hs_date_entered_8070190` (present as PROPERTY_HS_V2_DATE_ENTERED_8070190).
    -- Verify both pipeline/stage IDs in the dbt repo before merging — the 1796976 ID
    -- may be obsolete or HPD-renamed. For now using the 8070190 column only; if
    -- the obsolete one is still referenced downstream, add a coalesce.
    ,d.property_hs_v2_date_entered_8070190                                               as demo_completed_date
    ,d.property_hubspot_owner_id                                                         as ownerid
    ,d.property_chargebee_customer_id                                                    as chargebee_customer_id
    ,d.property_length_of_initial_term                                                   as term
    ,d.property_payment_terms                                                            as payment_terms
    ,extract(epoch_second from d.property_subscription_start_date)                       as sub_start_date_unix
    ,d.property_subscription_start_date::timestamp                                       as sub_start_date
    ,extract(epoch_second from d.property_subscription_end_date)                         as sub_end_date_unix
    ,d.property_subscription_end_date::timestamp                                         as sub_end_date
    ,d.property_hs_arr                                                                   as hubspot_arr
    ,d.property_hs_tcv                                                                   as hubspot_total_contract_value
    ,d.property_hs_mrr                                                                   as hubspot_mrr
    ,d.property_recurring_revenue_inactive_date                                          as recurring_revenue_inactive_ts
    ,d.property_recurring_revenue_inactive_reason                                        as recurring_revenue_inactive_reason
    ,d.property_recurring_revenue_amount                                                 as recurring_revenue_amount
    -- properties_versions intentionally REMOVED. Downstream stg_deals_event_log.sql
    -- needs a separate rewrite using object_properties_history (see notes.md).
from hubspot_platform_data.v2_daily.objects_deals d
    left join primary_company pc on pc.dealid = d.objectid
where 1=1
    -- HPD does not retain soft-deleted records; no `not isdeleted` filter needed.
    -- Test-deal exclusion preserved verbatim from original model.
    and d.objectid::string not in
    (
        --'5587669522' ,'4891058476' ,'10007910288' ------existed in code but unclear why so keeping for reference
        ------------   deals identified as tests based on manual review of test name -------------
        '18823649845', '18823404898', '18823468344', '15225707603', '14254184601', '12346364969', '17378604158'
        ,'14217028629', '16911993219', '8240549955', '14083846200', '12053929295', '12037944163', '13647628205'
        ,'15286594685', '11677884165', '13233015195', '13175258704', '15978386186', '16811842952', '9601366695'
        ,'16496368039', '18554820936', '12052907632', '12480565168', '10985307403', '13164696701', '17690561300'
        ,'16577133477'
    )
