module Person

    Wanted_properties = [
	    "_id",
	    "@displayName",
	    "types",
	    "gender",
	    "birthDate",
	    "deathDate",
	    "notes",
	    "children"
	]
    New_prop_names = [
	    "id",
	    "displayName_s",
	    "types_ss",
	    "gender_s",
	    "birthDate_i",
	    "deathDate_i",
	    "notes_t",
	    "children_s"
	]

    Relation_types = [
	"hasResidenceLocation",
	"hasBirthPlace",
	"hasDeathPlace",
	"hasMaritalStatus",
	"hasSocialClass",
	"hasEducation",
	"hasReligion",
	"hasProfession",
	"hasFinancialSituation",
	"isMemberOf"
    ]

    Wanted_relations = [
	"relatedLocations_ss",
	"birthPlace_ss",
	"deathPlace_ss",
	"maritalStatus_ss",
	"socialClass_ss",
	"education_ss",
	"religion_ss",
	"profession_ss",
	"financialSituation_ss",
	"memberships_ss",
    ]

    
    def Person.build_person obj
	new_person = Hash.new
	new_person['type_s'] = "person"
	Wanted_properties.each do |property|
	    if (property.eql?("birthDate") || property.eql?("deathDate")) && !obj[property].nil?
		new_person[New_prop_names[Wanted_properties.index(property)]] = obj[property].to_i
	    else
		new_person[New_prop_names[Wanted_properties.index(property)]] = obj[property]
	    end
	end
	new_person['modified_l'] = obj['^modified']['timeStamp']
	if !obj['names'].nil?
	    new_person['name_t'] = Person.build_name obj['names']
	end

	new_person = Person.build_relations(obj, new_person)

	return new_person
    end
    
    def Person.build_name names
	new_names = Array.new
	names.each do |name|
	    build_name = Hash.new
	    name['components'].each do |component|
		if build_name[component['type']].nil?
		    build_name[component['type']] = component['value']
		else
		    build_name[component['type']] << " #{component['value']}"
		end
	    end
	    forename = build_name['FORENAME']
	    gen_name = build_name['GEN_NAME']
	    surname = build_name['SURNAME']
	    add_name = build_name['ADD_NAME']
	    role_name = build_name['ROLE_NAME']
	    name_link = build_name['NAME_LINK']
    
	    complete_name = "#{role_name} #{forename} #{gen_name} #{name_link} #{surname} #{add_name}"
	    complete_name.strip!
	    complete_name.gsub!(/  +/," ")
	    new_names << complete_name
	end
    
	return new_names.join(" ")
    end

    def Person.build_relations old_person, new_person
	Wanted_relations.each_with_index do |rel,ind|
	    new_person[rel] = Array.new
	    if ind==0
		if !old_person['@relations'].nil?
		    (0..2).each do |ind_2|
			if !old_person['@relations'][Relation_types[ind_2]].nil?
			    old_person['@relations'][Relation_types[ind_2]].each do |rt|
				if rt['accepted']
				    new_person[rel] << rt['displayName']
				end
			    end
			end
		    end
		end
	    else
		if !old_person['@relations'].nil?
		    if !old_person['@relations'][Relation_types[ind]].nil?
			old_person['@relations'][Relation_types[ind]].each do |rt|
			    if rt['accepted']
				new_person[rel] << rt['displayName']
			    end
			end
		    end
		end
	    end
	    new_person[rel].uniq!
	end
	return new_person
    end

end

