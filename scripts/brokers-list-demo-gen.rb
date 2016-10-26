#! /usr/bin/env ruby

require 'date'
require 'json'

@details_example_no = 0
def create_employer_details_example_file(content) 
    path = "enroll/employer/employer_details/response/example_#{@details_example_no}.json"
    File.write("#{__dir__}/../#{path}", JSON.pretty_generate(content))
    @details_example_no += 1
    "https://raw.githubusercontent.com/dchealthlink/HBX-mobile-app-APIs/master/#{path}"
end

@roster_example_no = 0
def create_employee_roster_example_file(content) 
    path = "enroll/employer/employee_roster/response/example_#{@roster_example_no}.json"
    File.write("#{__dir__}/../#{path}", JSON.pretty_generate(content))
    @roster_example_no += 1
    "https://raw.githubusercontent.com/dchealthlink/HBX-mobile-app-APIs/master/#{path}"
end

class Date
    def on(mday)
        Date.new(year, mon, mday)
    end
end

class PlanYear
    def initialize(start_date, in_open_enrollment, in_pending_renewal)
        @start_date = start_date
        @in_open_enrollment = in_open_enrollment
        @in_pending_renewal = in_pending_renewal
    end

    def in_pending_renewal
        @in_pending_renewal
    end

    def end_of_open_enrollment
        (@start_date << 1).on(13)
    end

    def renewal_deadline
        end_of_open_enrollment - 3
    end

    def earliest_open_enrollment_begins
        @start_date << 2
    end

    def open_enrollment_begins
        earliest_open_enrollment_begins if @in_open_enrollment 
    end

    def renewal_begins
        @start_date << 3
    end

    def plan_year_begins
        @start_date
    end

    def in_renewal_OE
        @in_open_enrollment && (@start_date.month > 6)
    end

    def date_fields
        """\"open_enrollment_begins\" : #{fmt(open_enrollment_begins)},
            \"open_enrollment_ends\" : #{fmt(end_of_open_enrollment)},
            \"plan_year_begins\": #{fmt(plan_year_begins)},
            \"renewal_application_available\": #{fmt(renewal_begins)},
            \"renewal_application_due\": #{fmt(renewal_deadline)}"""
    end
end


def now 
    Date.parse(Time.now.to_s)
end

def plan_starting_in(months, in_open_enrollment = false, in_pending_renewal = false)
    PlanYear.new( (now >> months).on(1), in_open_enrollment, in_pending_renewal)
end

def fmt(dt)
    dt.strftime("%Y-%m-%d") if dt
end

def contact(first: "", last: "", phone: "", mobile: "", email: "", address_1: "", address_2: "", 
    city: "", state: "", zip: "")
    JSON.pretty_generate(
        {
                  first: "#{first}",
                  last: "#{last}",
                  phone: "#{phone}",
                  mobile: "#{mobile}",
                  emails: ["#{email}"],
                  address_1: "#{address_1}",
                  address_2: "#{address_2}",
                  city: "#{city}",
                  state: "#{state}",
                  zip: "#{zip}" 
                }, {indent: "                  "})
end


def staffer(first: "John", last: "Doe", phone: "202-468-6571", mobile: "202-468-6571", email: "john.doe@example.com")
    contact(first: first, last: last, phone: phone, mobile: mobile, email: email)
end

def office(first: "Primary", last: "Office", phone: "202-468-6571", email: "", 
            address_1: "609 H St. NE", address_2: "", city: "Washington", state: "DC", zip: "20001")
    contact(first: first, last: last, phone: phone, email: email, address_1: address_1, address_2:address_2,
        city: city, state: state, zip: zip)
end

def json_section(obj, opts)
    JSON.pretty_generate(obj, opts).gsub(/\{|\}/, '').rstrip
end

def parse_person(person_string)
    gender, first, mid, last, sfx, dob, ssn, hired = person_string.split
    result = { 
        first_name: first,
        middle_name: mid,
        last_name: last,
        name_suffix: sfx,
        date_of_birth: dob,
        ssn_masked: ssn,
        gender: gender
    }
    result[:hired_on] = hired if hired
    result
end

def participation(employer_name, total, enrolled, waived, plan_year)
  period_types = ["active"]
  period_types << "renewal" if plan_year.in_renewal_OE
  coverage_options = { health: ["Enrolled", "Waived", "Not Enrolled", "Terminated"], 
                       dental:  ["Enrolled", "Not Enrolled", nil, nil] }
  ee_contrib = (enrolled * 425.00 * ((waived + 1) ** 0.2)).round(2)
  er_contrib = (enrolled * 770.00 * ((waived + 1) ** 0.22)).round(2)

  employee_data = [["male Sammy R. Davis Jr. 1925-12-08 ***-**-6789 2008-12-08",   
                      ["female Tracey M. Davis Jr. 1965-08-07 ***-**-9909",
                       "male Manny D. Davis X 1971-09-09 ***-**-5505"] ], 
                   ["male Frank S. Sinatra III 1915-12-12 ***-**-2000 2007-12-12", [] ], 
                   ["male Dean D. Martin Sr. 1917-06-07 ***-**-4566 2012-03-03",   [] ],
                   ["female Abigail M. Yates PhD. 1975-12-08 ***-**-6001 2008-10-08",   
                      ["male Kevin R. Beckman X. 1985-08-07 ***-**-7603"] ], 
                   ["female Jillian S. Holtzmann PhD. 1985-11-11 ***-**-2050 2009-11-12", [] ], 
                   ["female Patty D. Tolan Cdtr 1987-06-06 ***-**-4546 2015-04-03",   [] ], 
                   ["female Erin S. Gilbert PhD. 1969-03-01 ***-**-4554 2016-01-01",   [] ]
                  ]

  roster = {
    employer_name: "#{employer_name}",
    roster: employee_data.each_with_index.map do |e, index|
              employee = parse_person(e[0])
              termination_date = nil
              dependents = e[1].map { |d| parse_person(d) }
              enrollments = {}
              period_types.each_with_index do |period_type, period_type_index|
                enrollments[period_type] = {}
                coverage_options.keys.each do |coverage_kind|
                  which = (index + period_type_index + employer_name.length) % coverage_options[:health].length
                  status = coverage_options[coverage_kind][which]
                  if status then
                    enrollment = { status: status }
                    case status when "Enrolled", "Waived", "Terminated"
                      er_cost = (status == "Enrolled") ? (er_contrib / employee_data.length).round(2) : 0.0
                      ee_cost = (status == "Enrolled") ? (ee_contrib / employee_data.length).round(2) : 0.0
                      enrollment[:employer_contribution] = er_cost
                      enrollment[:employee_cost] = ee_cost
                      enrollment[:total_premium] = (er_cost + ee_cost).round(2)
                      enrollment[:plan_name] = "KP DC Silver 2000/35"
                      enrollment[:plan_type] = "HMO"
                      enrollment[:metal_level] = "Silver"
                      enrollment[:benefit_group_name] = (index == 1) ? "Closers" : "Other Employees"
                      if status == "Terminated" then
                        enrollment[:terminated_on] = Date.today
                        enrollment[:terminate_reason] = "I have coverage through an individual market health plan"
                      end
                    end
                    enrollments[period_type][coverage_kind] = enrollment
                  end
                end
              end
              
              employee[:id] = @roster_example_no * 100 + index
              employee[:enrollments] = enrollments
              employee[:is_business_owner] = (index == 1) #Frank is the Chairman of the Board
              employee[:dependents] = dependents
              employee
            end
  }


  summary = {
    employer_name: "#{employer_name}",
    employees_total: total,
    employees_enrolled: enrolled,
    employees_waived: waived,
    open_enrollment_begins:        fmt(plan_year.open_enrollment_begins),
    open_enrollment_ends:          fmt(plan_year.end_of_open_enrollment),
    plan_year_begins:              fmt(plan_year.plan_year_begins),
    renewal_in_progress:           plan_year.in_pending_renewal,
    renewal_application_available: fmt(plan_year.renewal_begins),
    renewal_application_due:       fmt(plan_year.renewal_deadline),
    binder_payment_due: nil,
    minimum_participation_required: (total * 2.0 / 3.0).to_i,
    billing_report_date: fmt(now >> 1),
    active_general_agency: (total < 5) ? nil : "Betadyne General Agency, Inc.",
  }

  details = summary.clone
  details[:total_premium] = ee_contrib + er_contrib
  details[:employee_contribution] = ee_contrib
  details[:employer_contribution] = er_contrib
  details[:plan_offerings] = Hash[period_types.each_with_index.map do |period_type, period_type_index|
    [period_type, ["CEO’S & MANAGERS", "CADDIES & MAINTENANCE"].each_with_index.map do |group_name, group_name_index|
      group_difference = group_name_index * -10
      health_plans = [{
                        reference_plan_name: 'KP DC PLATINUM 500/20/DENTAL/PED DENTAL/SEL',
                        reference_plan_HIOS_id: "94506DC0350009-01",
                        carrier_name: 'Kaiser',
                        plan_type: 'HMO',
                        metal_level: 'Platinum',
                        plan_option_kind: 'single_carrier',
                        plans_by: 'All Plans From a Single Carrier',
                        plans_by_summary_text: 'All Kaiser Plans',
                        employer_contribution_by_relationship: { 
                            employee: 90 + group_difference, 
                            spouse: 80 + group_difference,
                            domestic_partner: 70 + group_difference,
                            child_under_26: 60  + group_difference
                        },   
                        estimated_employer_max_monthly_cost: 6000 + (group_difference * 12),
                        estimated_plan_participant_min_monthly_cost: 312 + (group_difference * 2),
                        estimated_plan_participant_max_monthly_cost: 954  + (group_difference * 2)
                    },{
                        reference_plan_name: 'UHC CHOICE PLUS POS GOLD 0 B',
                        reference_plan_HIOS_id: "78606AB0440009-05",
                        carrier_name: 'United Health Care',
                        plan_type: 'POS',
                        metal_level: 'Gold',
                        plan_option_kind: 'single_plan',
                        plans_by: 'A Single Plan',
                        plans_by_summary_text: 'Reference Plan Only',
                        employer_contribution_by_relationship: { 
                           employee: 50 + group_difference, 
                           spouse: nil, 
                           domestic_partner: nil, 
                           child_under_26: 0
                        },   
                        estimated_employer_max_monthly_cost: 6000 + (group_difference * 12),
                        estimated_plan_participant_min_monthly_cost: 312 + (group_difference * 2),
                        estimated_plan_participant_max_monthly_cost: 954  + (group_difference * 2)
                    }]  

      dental_plans = [{
                         reference_plan_name: 'BlueDental Preferred',
                         reference_plan_HIOS_id: "94506DC0350009-01",
                         carrier_name: 'CareFirst',
                         plan_type: 'PPO',
                         plan_option_kind: 'single_plan',
                         plans_by: 'Custom (3 Plans)',
                         plans_by_summary_text: 'Custom (3 Plans)',
                         elected_dental_plans: [
                            { carrier_name: 'CareFirst', plan_name: 'BlueDental Preferred '},
                            { carrier_name: 'CareFirst', plan_name: 'BlueDental Traditional'},
                            { carrier_name: 'Delta Dental ', plan_name: 'Delta Dental PPO Basic Plan for Families for Small Businesses '}
                         ],
                         employer_contribution_by_relationship: { 
                            employee: 80, 
                            spouse: 70,
                            domestic_partner: 60,
                            child_under_26: 50
                        },
                        estimated_employer_max_monthly_cost: 2000,
                        estimated_plan_participant_min_monthly_cost: 92,
                        estimated_plan_participant_max_monthly_cost: 54 
                    }, nil]

      { 
          benefit_group_name: group_name,
          eligibility_rule: 'First of the month following or coinciding with date of hire',
          health: health_plans[period_type_index],
          dental: dental_plans[period_type_index]
      }
    end]
  end]

  summary[:employer_details_url] = create_employer_details_example_file(details)
  summary[:employee_roster_url] = create_employee_roster_example_file(roster)
  json_section(summary, {indent: "            "})       
end


min_months_to_renew = if now.mday > 10 then 2 else 1 end
min_months_to_enroll = if now.mday > 13 then 2 else 1 end

in_open_enrollment = plan_starting_in(2, true)
late_open_enrollment = plan_starting_in(min_months_to_enroll, true)
in_renewal = plan_starting_in(2, false, true)
early_renewal  = plan_starting_in(3, false, true)
late_to_renewal = plan_starting_in(min_months_to_renew, false, true)

text = """
 {
    \"broker_agency\" : \"Bob's Brokers\",
    \"broker_name\" : \"Bill\",
    
    \"broker_clients\": [
            {
            #{participation("Courageous Consulting, LLC", 30, 5, 0, late_open_enrollment)},
            
            \"contact_info\": [
                #{staffer(first: "Bob", phone: "", email: "bob@courageous-consulting.com")},
                #{office(address_1: "1600 Pennsylvania Avenue")}
            ]
            },
            {
            #{participation("National Network to End Domestic Abuse", 41, 10, 5, in_open_enrollment)},
            \"contact_info\": [
                #{staffer(first: "Jane", phone: "202-555-0000", email: "contact@endabuse.org")},
                #{office(address_1: "1600 New Hampshire Avenue")}
            ]
            },
            {
            #{participation("District Yoga", 30, 20, 3, in_open_enrollment)},
            \"contact_info\": [      
                #{staffer(first: "Priya", last: "Chandragupta", email: "contact@districtyoga.com")},
                #{office(address_1: "1600 New York Avenue", phone: "202-555-0212")}
            ]
            },
            {
            #{participation("DC Cupcakes", 50, 40, 7, plan_starting_in(5))},
            \"contact_info\": [      
                #{staffer(first: "Emile", last: "Della Noce", email: "contact@dccupcakes.com")},
                #{office(address_1: "1600 Rhode Island Avenue", phone: "202-555-0313")}
            ]
            },
            {
            #{participation("OPEN Art Studio", 30, 20, 3, late_open_enrollment)},
            \"contact_info\": [      
                #{staffer(first: "Yona", last: "Mendelssohn", email: "yona@openart.org")},
                #{staffer(first: "Noam", last: "Mendelssohn", email: "noam@openart.org")},
                #{office(address_1: "1600 Arizona Avenue", phone: "202-555-0414")}
            ]
            },
            {
            #{participation("Best Brau Brewing Company", 30, 20, 6, in_renewal)},
            \"contact_info\": [      
                #{staffer(first: "Heinrich", last: "Biergarten", email: "heini@bestbrau.com")},
                #{staffer(first: "Ulrich", last: "Suufersohn", email: "ueli@bestbrau.com")},
                #{office(address_1: "1600 Nebraska Avenue", phone: "202-555-0515")},
                #{office(first: "Branch", address_1: "6600 Nebraska Avenue")}
            ]
            },
            {
            #{participation("Bistrot Du Monde", 33, 20, 4, late_to_renewal)},
            \"contact_info\": [      
                #{staffer(first: "Claudette", last: "Noire", email: "cnoire@dumonde.com")},
                #{staffer(first: "Aloise", last: "Rouge", email: "arouge@dumonde.com")},
                #{office(address_1: "1600 Louisiana Avenue", phone: "202-555-0005")}
            ]
            },  
            {
            #{participation("Bistrot Du Bois", 15, 7, 7, early_renewal)},
            \"contact_info\": [      
                #{staffer(first: "Claudette", last: "Blanc", email: "cblan@dubois.com")},
                #{staffer(first: "Aloise", last: "Vert", email: "avert@dubois.com")},
                #{office(address_1: "1600 Maine Avenue", phone: "202-555-0006")}
            ]
            },
            {
            #{participation("Strategy & Tactics Game Shop", 6, 2, 2, plan_starting_in(8))},
            \"contact_info\": [      
                #{staffer(first: "Maria Susanna", last: "Ludador", email: "contact@stgames.com")},
                #{office(address_1: "1600 Georgia Avenue", phone: "202-555-0007")}
            ]
            },
            {
            #{participation("Portia's Tea Bar", 12, 9, 2, plan_starting_in(7))},
            \"contact_info\": [      
                #{staffer(first: "Portia", last: "Binglesworth-Inglesham", email: "portia@helloportia.com")},
                #{office(address_1: "1600 Alabama Avenue", phone: "202-555-0008")},
                #{office(first: "Branch", address_1: "1600 Utah Avenue", address_2: "Suite 500", phone: "202-555-0009")}
            ]
            },
            {
            #{participation("J. Grigory Food Trucks & Fine Comestibles", 66, 50, 0, plan_starting_in(6))},
            \"contact_info\": [
                #{staffer(first: "Joe", last: "Grigory", email: "jgrigory@jgrigory.com")},
                #{office(address_1: "1600 North Carolina Avenue", phone: "202-555-0009")}
            ]
            }
    ]
}
"""

print text



