# Save Utah — Seed Data
# Run with: bin/rails db:seed
# Idempotent: uses find_or_initialize_by to avoid duplicates

puts "Seeding Save Utah database..."

# ============================================================
# EXECUTIVE OFFICIALS (Manual — rarely changes)
# ============================================================
executives = [
  {
    first_name: "Spencer",
    last_name: "Cox",
    title: "Governor of Utah",
    position_type: :governor,
    level: :state,
    party: "Republican",
    phone: "(801) 538-1000",
    email: "governor@utah.gov",
    website_url: "https://governor.utah.gov",
    twitter_handle: "prior2GL",
    office_address: "Utah State Capitol, Suite 200, Salt Lake City, UT 84114"
  },
  {
    first_name: "Deidre",
    last_name: "Henderson",
    title: "Lieutenant Governor of Utah",
    position_type: :lt_governor,
    level: :state,
    party: "Republican",
    phone: "(801) 538-1000",
    email: "ltgovernor@utah.gov",
    website_url: "https://ltgovernor.utah.gov",
    office_address: "Utah State Capitol, Suite 220, Salt Lake City, UT 84114"
  },
  {
    first_name: "Derek",
    last_name: "Brown",
    title: "Attorney General of Utah",
    position_type: :attorney_general,
    level: :state,
    party: "Republican",
    phone: "(801) 366-0260",
    email: "uag@agutah.gov",
    website_url: "https://attorneygeneral.utah.gov",
    office_address: "Utah State Capitol, Suite 230, Salt Lake City, UT 84114"
  },
  {
    first_name: "Tina",
    last_name: "Cannon",
    title: "State Auditor of Utah",
    position_type: :state_auditor,
    level: :state,
    party: "Republican",
    phone: "(801) 538-1025",
    website_url: "https://auditor.utah.gov",
    office_address: "Utah State Capitol Complex, East Building, Salt Lake City, UT 84114"
  },
  {
    first_name: "Marlo",
    last_name: "Oaks",
    title: "State Treasurer of Utah",
    position_type: :state_treasurer,
    level: :state,
    party: "Republican",
    phone: "(801) 538-1042",
    website_url: "https://treasurer.utah.gov",
    office_address: "Utah State Capitol Complex, East Building, Salt Lake City, UT 84114"
  }
]

executives.each do |attrs|
  full_name = attrs[:full_name] || "#{attrs[:first_name]} #{attrs[:last_name]}"
  rep = Representative.find_or_initialize_by(
    first_name: attrs[:first_name],
    last_name: attrs[:last_name],
    position_type: attrs[:position_type]
  )
  rep.assign_attributes(attrs.merge(full_name: full_name, active: true))
  rep.save!
  puts "  #{rep.active? ? 'Updated' : 'Created'} #{rep.display_name}"
end

# ============================================================
# FEDERAL DELEGATION (Seed a few key reps for demo purposes)
# ============================================================
federal_reps = [
  {
    first_name: "Mike",
    last_name: "Lee",
    title: "U.S. Senator",
    position_type: :us_senator,
    level: :federal,
    chamber: "Senate",
    party: "Republican",
    phone: "(202) 224-5444",
    website_url: "https://lee.senate.gov",
    twitter_handle: "SenMikeLee",
    bioguide_id: "L000577"
  },
  {
    first_name: "John",
    last_name: "Curtis",
    title: "U.S. Senator",
    position_type: :us_senator,
    level: :federal,
    chamber: "Senate",
    party: "Republican",
    phone: "(202) 224-5251",
    website_url: "https://curtis.senate.gov",
    twitter_handle: "SenJohnCurtis",
    bioguide_id: "C001114"
  },
  {
    first_name: "Blake",
    last_name: "Moore",
    title: "U.S. Representative, District 1",
    position_type: :us_representative,
    level: :federal,
    chamber: "House",
    party: "Republican",
    district: "1",
    phone: "(202) 225-0453",
    website_url: "https://blakemoore.house.gov",
    bioguide_id: "M001216"
  },
  {
    first_name: "Celeste",
    last_name: "Maloy",
    title: "U.S. Representative, District 2",
    position_type: :us_representative,
    level: :federal,
    chamber: "House",
    party: "Republican",
    district: "2",
    phone: "(202) 225-3011",
    website_url: "https://maloy.house.gov",
    bioguide_id: "M001226"
  },
  {
    first_name: "Mike",
    last_name: "Kennedy",
    title: "U.S. Representative, District 3",
    position_type: :us_representative,
    level: :federal,
    chamber: "House",
    party: "Republican",
    district: "3",
    phone: "(202) 225-7751",
    website_url: "https://kennedy.house.gov",
    bioguide_id: "K000404"
  },
  {
    first_name: "Burgess",
    last_name: "Owens",
    title: "U.S. Representative, District 4",
    position_type: :us_representative,
    level: :federal,
    chamber: "House",
    party: "Republican",
    district: "4",
    phone: "(202) 225-3011",
    website_url: "https://owens.house.gov",
    bioguide_id: "O000086"
  }
]

federal_reps.each do |attrs|
  full_name = "#{attrs[:first_name]} #{attrs[:last_name]}"
  rep = Representative.find_or_initialize_by(bioguide_id: attrs[:bioguide_id])
  rep.assign_attributes(attrs.merge(full_name: full_name, active: true))
  rep.save!
  puts "  #{rep.display_name}"
end

# ============================================================
# SAMPLE BILLS
# ============================================================
sample_bills = [
  {
    title: "Protecting Utah's Public Lands Act",
    bill_number: "S.1234",
    summary: "A bill to designate certain lands in Utah as wilderness and protect them from development.",
    editorial_summary: "This bill would permanently protect over 1 million acres of Utah's most iconic landscapes from mining and drilling, including areas near Arches and Canyonlands National Parks.",
    status: "In Committee",
    level: :federal,
    chamber: "Senate",
    session_year: 2025,
    session_name: "119th Congress",
    featured: true,
    introduced_on: Date.new(2025, 3, 15),
    last_action_on: Date.new(2025, 6, 1),
    data_source: "seed"
  },
  {
    title: "Utah Clean Air Standards Act",
    bill_number: "HB 245",
    summary: "Establishes new emission standards for industrial facilities along the Wasatch Front to improve air quality.",
    editorial_summary: "Utah's air quality regularly ranks among the worst in the nation during winter inversions. This bill would set stricter emission standards for refineries and industrial plants along the Wasatch Front.",
    status: "House Floor",
    level: :state,
    chamber: "House",
    session_year: 2025,
    session_name: "2025 General Session",
    featured: true,
    introduced_on: Date.new(2025, 1, 20),
    last_action_on: Date.new(2025, 2, 15),
    data_source: "seed"
  },
  {
    title: "Great Salt Lake Preservation Fund",
    bill_number: "SB 89",
    summary: "Creates a dedicated state fund to support water conservation and restoration efforts for the Great Salt Lake.",
    editorial_summary: "The Great Salt Lake is at historically low levels, threatening Utah's ecosystem, economy, and public health. This bill would create a $200M fund for water conservation and restoration.",
    status: "Enrolled",
    level: :state,
    chamber: "Senate",
    session_year: 2025,
    session_name: "2025 General Session",
    featured: true,
    introduced_on: Date.new(2025, 1, 10),
    last_action_on: Date.new(2025, 3, 1),
    data_source: "seed"
  },
  {
    title: "Fiscal Responsibility and Government Efficiency Act",
    bill_number: "HR 5678",
    summary: "A bill to reduce federal spending and improve government efficiency through agency restructuring.",
    editorial_summary: "This bill proposes significant cuts to federal programs that directly impact Utah, including potential reductions to public lands management and national park funding.",
    status: "Passed House",
    level: :federal,
    chamber: "House",
    session_year: 2025,
    session_name: "119th Congress",
    featured: false,
    introduced_on: Date.new(2025, 2, 1),
    last_action_on: Date.new(2025, 5, 20),
    data_source: "seed"
  }
]

sample_bills.each do |attrs|
  bill = Bill.find_or_initialize_by(bill_number: attrs[:bill_number], session_year: attrs[:session_year])
  bill.assign_attributes(attrs)
  bill.save!
  puts "  #{bill.bill_number}: #{bill.title}"
end

# ============================================================
# SAMPLE VOTES
# ============================================================
puts "\nSeeding sample votes..."

# Get some reps and bills for vote data
lee = Representative.find_by(last_name: "Lee", position_type: :us_senator)
curtis = Representative.find_by(last_name: "Curtis", position_type: :us_senator)
moore = Representative.find_by(last_name: "Moore")
maloy = Representative.find_by(last_name: "Maloy")
kennedy = Representative.find_by(last_name: "Kennedy", first_name: "Mike")
owens = Representative.find_by(last_name: "Owens")

public_lands_bill = Bill.find_by(bill_number: "S.1234")
efficiency_bill = Bill.find_by(bill_number: "HR 5678")

if public_lands_bill && lee && curtis
  [
    { representative: lee, bill: public_lands_bill, position: :no, voted_on: Date.new(2025, 5, 15) },
    { representative: curtis, bill: public_lands_bill, position: :yes, voted_on: Date.new(2025, 5, 15) }
  ].each do |vote_attrs|
    vote = Vote.find_or_initialize_by(
      representative: vote_attrs[:representative],
      bill: vote_attrs[:bill]
    )
    vote.assign_attributes(vote_attrs.merge(data_source: "seed"))
    vote.save!
    puts "  #{vote.representative.last_name} voted #{vote.position} on #{vote.bill.bill_number}"
  end
end

if efficiency_bill && moore && maloy && kennedy && owens
  [
    { representative: moore, bill: efficiency_bill, position: :yes, voted_on: Date.new(2025, 5, 20) },
    { representative: maloy, bill: efficiency_bill, position: :yes, voted_on: Date.new(2025, 5, 20) },
    { representative: kennedy, bill: efficiency_bill, position: :yes, voted_on: Date.new(2025, 5, 20) },
    { representative: owens, bill: efficiency_bill, position: :yes, voted_on: Date.new(2025, 5, 20) }
  ].each do |vote_attrs|
    vote = Vote.find_or_initialize_by(
      representative: vote_attrs[:representative],
      bill: vote_attrs[:bill]
    )
    vote.assign_attributes(vote_attrs.merge(data_source: "seed"))
    vote.save!
    puts "  #{vote.representative.last_name} voted #{vote.position} on #{vote.bill.bill_number}"
  end
end

# ============================================================
# ACTION SCRIPTS
# ============================================================
puts "\nSeeding action scripts..."

cox = Representative.find_by(last_name: "Cox", position_type: :governor)

scripts = [
  {
    title: "Call Governor Cox About Public Lands",
    script_template: "Hi, my name is [YOUR NAME] and I'm a Utah resident calling about public lands protection. I urge Governor [REP_NAME] to support legislation that protects Utah's iconic landscapes from development. Our national parks and wilderness areas are Utah's greatest assets. Thank you.",
    context: "Utah's public lands face increasing pressure from energy development and resource extraction.",
    action_type: :call,
    representative: cox,
    featured: true,
    sort_order: 1
  },
  {
    title: "Tell Senator Curtis to Support the SAVE Act",
    script_template: "Hello, I'm calling to ask Senator [REP_NAME] to co-sponsor the SAVE Act to protect Utah's public lands. As a constituent, I believe preserving our natural heritage is critical for Utah's economy and quality of life. Please support this legislation. Thank you for your time.",
    context: "The SAVE Act would designate additional wilderness areas in Utah and provide funding for conservation.",
    action_type: :call,
    representative: curtis,
    featured: true,
    sort_order: 2
  },
  {
    title: "Email Your Rep About Clean Air",
    script_template: "Dear [REP_TITLE] [REP_NAME],\n\nI'm writing as a concerned Utah resident about our state's air quality crisis. During winter inversions, our air quality regularly exceeds EPA limits. I urge you to support HB 245, the Utah Clean Air Standards Act, which would establish stricter emission standards for industrial facilities.\n\nOur families deserve clean air to breathe.\n\nSincerely,\n[YOUR NAME]",
    context: "Utah's Wasatch Front regularly experiences dangerous air quality during winter temperature inversions.",
    action_type: :email,
    featured: true,
    sort_order: 3
  },
  {
    title: "Call Senator Lee About Great Salt Lake",
    script_template: "Hi, I'm a Utah constituent calling about the Great Salt Lake crisis. The lake is at historic lows and poses serious environmental and health risks. I urge Senator [REP_NAME] to support federal funding for Great Salt Lake restoration. This is a nonpartisan issue that affects all Utahns. Thank you.",
    context: "The Great Salt Lake has lost 73% of its water since 1987, exposing toxic lakebed dust.",
    action_type: :call,
    representative: lee,
    featured: true,
    sort_order: 4
  }
]

scripts.each do |attrs|
  script = ActionScript.find_or_initialize_by(title: attrs[:title])
  script.assign_attributes(attrs.merge(active: true))
  script.save!
  puts "  #{script.title}"
end

# ============================================================
# FEATURED ITEMS
# ============================================================
puts "\nSeeding featured items..."

# Featured spotlight items for homepage
[cox, lee, curtis, moore].compact.each_with_index do |rep, i|
  item = FeaturedItem.find_or_initialize_by(
    featurable_type: "Representative",
    featurable_id: rep.id,
    section: :spotlight
  )
  item.assign_attributes(
    headline: rep.short_label,
    description: "#{rep.title} — #{rep.party}",
    sort_order: i,
    active: true
  )
  item.save!
  puts "  Spotlight: #{rep.full_name}"
end

# ============================================================
# ISSUES (Accountability Scorecards)
# ============================================================
puts "\nSeeding issues..."

issues_data = [
  {
    name: "Stop Taxpayer Benefits to Illegal Immigrants",
    icon: "🛑",
    stance_label: "Protect Taxpayers",
    against_label: "Funded Illegal Benefits",
    description: "Utah taxpayers are footing the bill for benefits that go to people who broke the law to get here. Emergency Medicaid, in-state tuition, driver privilege cards — every dollar spent on illegal immigrants is a dollar stolen from Utah families who play by the rules. Our representatives need to choose: do they stand with the citizens who elected them, or do they keep writing blank checks to people who cut the line?",
    hero_headline: '19 Utah Senators Voted <span class="block text-utah-red">Against You</span>',
    hero_subheadline: 'They killed <strong class="text-white">HB 497</strong> — the bill to stop taxpayer-funded benefits for illegal immigrants. In-state tuition. Driver privilege cards. Non-emergency Medicaid. <strong class="text-utah-gold">Your tax dollars. Their choice.</strong>',
    hero_cta: "Here are their names and phone numbers. Let them know how you feel.",
    hero_stat_1: "45% of DUIs — unlicensed drivers",
    hero_stat_2: "40% of hit-and-runs — uninsured",
    og_title: "19 Utah Senators Voted to Keep Funding Illegal Immigrants With YOUR Tax Dollars",
    og_description: "They killed HB 497. Every one of them. Call them. Text them. Let them know you're watching.",
    sort_order: 0
  },
  {
    name: "No Driver's Licenses for Illegal Aliens (SAVE Act)",
    icon: "🗳️",
    stance_label: "Protect the Ballot Box",
    against_label: "Enabled Illegal Voting Risk",
    description: "The SAVE Act would require proof of citizenship to register to vote and prevent states from issuing driver's licenses that can be used as voter ID to illegal aliens. It's common sense: if you're not a citizen, you don't get to vote. Period. Any representative who opposes this is telling you they care more about padding voter rolls than protecting your vote.",
    sort_order: 1
  },
  {
    name: "End Insider Trading by Members of Congress",
    icon: "💰",
    stance_label: "Banned Congressional Trading",
    against_label: "Protected Insider Profits",
    description: "Members of Congress sit in classified briefings, get advance notice of regulations, and then trade stocks based on that information. It's insider trading — the same crime that sends regular Americans to prison. The TRUST Act and STOCK Act reforms would ban congressional stock trading. Any rep who votes against these bills is telling you their portfolio matters more than your trust.",
    sort_order: 2
  },
  {
    name: "No AI Data Centers Without Electric Bill Protections",
    icon: "⚡",
    stance_label: "Protected Ratepayers",
    against_label: "Let Big Tech Raise Your Bills",
    description: "Tech giants want to build massive AI data centers in Utah that consume as much electricity as entire cities. Without protections, YOUR electric bill goes up to subsidize their server farms. Utah's grid wasn't built for this, and ratepayers shouldn't be stuck with the tab. Any bill that allows new data center construction without rate impact protections is a giveaway to Big Tech at your expense.",
    sort_order: 3
  }
]

issues_data.each do |attrs|
  issue = Issue.find_or_initialize_by(name: attrs[:name])
  issue.assign_attributes(attrs.merge(active: true))
  issue.save!
  puts "  #{issue.icon} #{issue.name}"
end

# Link sample bills to issues for demo purposes
puts "\nLinking bills to issues..."

# Link the efficiency bill to the taxpayer issue
taxpayer_issue = Issue.find_by(name: "Stop Taxpayer Benefits to Illegal Immigrants")
if taxpayer_issue && efficiency_bill
  ib = IssueBill.find_or_initialize_by(issue: taxpayer_issue, bill: efficiency_bill)
  ib.assign_attributes(popular_position: :yes, sort_order: 0)
  ib.save!
  puts "  Linked #{efficiency_bill.bill_number} to #{taxpayer_issue.name}"
end

# Link the public lands bill to the taxpayer issue (as a secondary bill for demo)
if taxpayer_issue && public_lands_bill
  ib = IssueBill.find_or_initialize_by(issue: taxpayer_issue, bill: public_lands_bill)
  ib.assign_attributes(popular_position: :no, sort_order: 1)
  ib.save!
  puts "  Linked #{public_lands_bill.bill_number} to #{taxpayer_issue.name}"
end

# Link the efficiency bill to the insider trading issue
insider_issue = Issue.find_by(name: "End Insider Trading by Members of Congress")
if insider_issue && efficiency_bill
  ib = IssueBill.find_or_initialize_by(issue: insider_issue, bill: efficiency_bill)
  ib.assign_attributes(popular_position: :yes, sort_order: 0)
  ib.save!
  puts "  Linked #{efficiency_bill.bill_number} to #{insider_issue.name}"
end

# ============================================================
# 19 STATE SENATORS — "Stop Taxpayer Benefits" Blast
# ============================================================
puts "\nSeeding 19 state senators for the blast..."

state_senators = [
  { first_name: "Kirk", last_name: "Cullimore", district: "9", phone_work: "(801) 560-0769", email: "kcullimore@le.utah.gov" },
  { first_name: "Gene", last_name: "Davis", district: "3", phone_work: "(801) 484-6605", email: "gdavis@le.utah.gov" },
  { first_name: "Luz", last_name: "Escamilla", district: "1", phone_work: "(801) 544-8913", email: "lescamilla@le.utah.gov" },
  { first_name: "Lincoln", last_name: "Fillmore", district: "10", phone_work: "(801) 694-6800", email: "lfillmore@le.utah.gov" },
  { first_name: "Keith", last_name: "Grover", district: "15", phone_work: "(801) 420-1509", email: "kgrover@le.utah.gov" },
  { first_name: "Daniel", last_name: "Hemmert", district: "14", phone_work: "(801) 376-7792", email: "dhemmert@le.utah.gov" },
  { first_name: "David", last_name: "Hinkins", district: "27", phone_work: "(435) 650-0172", email: "dhinkins@le.utah.gov" },
  { first_name: "Ann", last_name: "Millner", district: "18", phone_work: "(801) 721-8404", email: "amillner@le.utah.gov" },
  { first_name: "Mike", last_name: "McKell", district: "11", phone_work: "(801) 427-5625", email: "mmckell@le.utah.gov" },
  { first_name: "Todd", last_name: "Weiler", district: "23", phone_work: "(801) 564-8575", email: "tweiler@le.utah.gov" },
  { first_name: "Evan", last_name: "Vickers", district: "28", phone_work: "(435) 586-2927", email: "evickers@le.utah.gov" },
  { first_name: "Curt", last_name: "Bramble", district: "16", phone_work: "(801) 805-5025", email: "cbramble@le.utah.gov" },
  { first_name: "Wayne", last_name: "Harper", district: "6", phone_work: "(801) 891-4740", email: "wharper@le.utah.gov" },
  { first_name: "Don", last_name: "Ipson", district: "29", phone_work: "(435) 634-1609", email: "dipson@le.utah.gov" },
  { first_name: "Derrin", last_name: "Owens", district: "24", phone_work: "(435) 820-2542", email: "dowens@le.utah.gov" },
  { first_name: "Scott", last_name: "Sandall", district: "17", phone_work: "(435) 225-2698", email: "ssandall@le.utah.gov" },
  { first_name: "Jerry", last_name: "Stevenson", district: "22", phone_work: "(801) 643-4440", email: "jstevenson@le.utah.gov" },
  { first_name: "Ronald", last_name: "Winterton", district: "26", phone_work: "(435) 613-2036", email: "rwinterton@le.utah.gov" },
  { first_name: "Michael", last_name: "Kennedy", district: "13", phone_work: "(801) 919-2309", email: "mkennedy@le.utah.gov" }
]

state_senators.each do |attrs|
  rep = Representative.find_or_initialize_by(
    first_name: attrs[:first_name],
    last_name: attrs[:last_name],
    position_type: :state_senator
  )
  rep.assign_attributes(
    full_name: "#{attrs[:first_name]} #{attrs[:last_name]}",
    title: "State Senator",
    position_type: :state_senator,
    level: :state,
    chamber: "Senate",
    party: "Republican",
    district: attrs[:district],
    phone_work: attrs[:phone_work],
    email: attrs[:email],
    active: true
  )
  rep.save!
  puts "  Sen. #{rep.full_name} (R) — District #{rep.district}"
end

# Create the state bill these senators voted NO on
puts "\nSeeding HB 497 (Stop Taxpayer Benefits bill)..."

hb497 = Bill.find_or_initialize_by(bill_number: "HB 497", session_year: 2025)
hb497.assign_attributes(
  title: "Taxpayer Protection — Prohibiting Public Benefits for Unauthorized Immigrants",
  summary: "Prohibits state-funded benefits including in-state tuition, driver privilege cards, and non-emergency Medicaid for individuals not lawfully present in Utah.",
  editorial_summary: "This bill would have ended taxpayer-funded benefits for illegal immigrants in Utah — in-state tuition subsidies, driver privilege cards, and non-emergency Medicaid. 19 Republican senators voted NO, siding with illegal immigrants over Utah taxpayers. They killed it.",
  status: "Failed in Senate",
  level: :state,
  chamber: "Senate",
  session_year: 2025,
  session_name: "2025 General Session",
  featured: true,
  introduced_on: Date.new(2025, 1, 28),
  last_action_on: Date.new(2025, 3, 7),
  data_source: "seed"
)
hb497.save!
puts "  #{hb497.bill_number}: #{hb497.title}"

# Create NO votes for each of the 19 senators
puts "\nSeeding NO votes..."

state_senators.each do |attrs|
  rep = Representative.find_by(first_name: attrs[:first_name], last_name: attrs[:last_name], position_type: :state_senator)
  next unless rep

  vote = Vote.find_or_initialize_by(representative: rep, bill: hb497)
  vote.assign_attributes(position: :no, voted_on: Date.new(2025, 3, 7), data_source: "seed")
  vote.save!
  puts "  #{rep.full_name} voted NO on #{hb497.bill_number}"
end

# Link HB 497 to the "Stop Taxpayer Benefits" issue
puts "\nLinking HB 497 to the taxpayer issue..."

taxpayer_issue = Issue.find_by(name: "Stop Taxpayer Benefits to Illegal Immigrants")
if taxpayer_issue && hb497
  ib = IssueBill.find_or_initialize_by(issue: taxpayer_issue, bill: hb497)
  ib.assign_attributes(popular_position: :yes, sort_order: 0)
  ib.save!
  puts "  Linked #{hb497.bill_number} to #{taxpayer_issue.name}"

  # Mark this issue as HOT
  taxpayer_issue.update!(hot: true)
  puts "  Marked '#{taxpayer_issue.name}' as HOT"
end

# Create 3 action scripts (call, text, email) for HB 497
puts "\nSeeding blast action scripts..."

blast_scripts = [
  {
    title: "Call Script — HB 497 Taxpayer Benefits",
    script_template: "Hi, my name is [YOUR NAME] and I'm a constituent in your district. I'm calling about HB 497, the bill to stop taxpayer-funded benefits for illegal immigrants. You voted NO on this bill and I want to know why. Utah families are struggling with the cost of living while our tax dollars subsidize in-state tuition and driver privilege cards for people who broke the law to get here. I expect you to represent the people who elected you, not illegal immigrants. I'll be watching your vote next session. Thank you.",
    context: "19 Republican state senators killed HB 497, which would have ended taxpayer-funded benefits for unauthorized immigrants in Utah.",
    action_type: :call,
    bill: hb497,
    featured: true,
    sort_order: 0
  },
  {
    title: "Text Script — HB 497 Taxpayer Benefits",
    script_template: "Sen. [REP_NAME]: You voted NO on HB 497 to stop taxpayer benefits for illegal immigrants. Utah families pay the price. We're watching. — A constituent",
    context: "Short SMS for texting your state senator about HB 497.",
    action_type: :text,
    bill: hb497,
    featured: true,
    sort_order: 1
  },
  {
    title: "Email Script — HB 497 Taxpayer Benefits",
    script_template: "Subject: Your NO vote on HB 497 — Taxpayer Benefits for Illegal Immigrants\n\nSenator [REP_NAME],\n\nI am a Utah resident and your constituent. I am deeply disappointed by your NO vote on HB 497, which would have prohibited taxpayer-funded benefits — including in-state tuition, driver privilege cards, and non-emergency Medicaid — for individuals not lawfully present in our state.\n\nUtah families are paying the bill for benefits that go to people who broke the law to get here. 45% of DUI arrests in some counties involve unlicensed drivers. 40% of hit-and-runs involve uninsured motorists with privilege cards. You voted to keep funding this.\n\nI expect you to stand with the taxpayers who elected you. I will remember this vote.\n\nSincerely,\n[YOUR NAME]",
    context: "Email template for contacting your state senator about HB 497.",
    action_type: :email,
    bill: hb497,
    featured: true,
    sort_order: 2
  }
]

blast_scripts.each do |attrs|
  script = ActionScript.find_or_initialize_by(title: attrs[:title])
  script.assign_attributes(attrs.merge(active: true))
  script.save!
  puts "  #{script.action_type}: #{script.title}"
end

puts "\nSeeding complete!"
puts "  Representatives: #{Representative.count}"
puts "  Bills: #{Bill.count}"
puts "  Votes: #{Vote.count}"
puts "  Action Scripts: #{ActionScript.count}"
puts "  Featured Items: #{FeaturedItem.count}"
puts "  Issues: #{Issue.count}"
puts "  Issue-Bill Links: #{IssueBill.count}"
