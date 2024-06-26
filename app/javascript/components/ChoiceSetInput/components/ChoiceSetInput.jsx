import 'es6-shim';
import PropTypes from 'prop-types';
import React, {useState, useEffect} from 'react';
import Translations from '../../Translations/components/Translations';
import AsyncPaginate from 'react-select-async-paginate';
import axios from "axios";
import Validation from "../modules/validation"

const ChoiceSetInput = (props) => {
  const {
    input,
    req,
    choiceSet: choiceSetProps,
    locales,
    fieldUuid,
    componentPolicies
  } = props

  const [choiceSet, _setChoiceSets] = useState(choiceSetProps)
  const [choiceData, _setChoiceData] = useState(choiceSetProps.selectedChoicesValue.map(s => s.value))
  const [isValid, setIsValid] = useState(Validation.isValid(
      req,
      input
  ))
  const [isActive, setIsActive] = useState(choiceSetProps.active)

  const setChoiceData = (index, value) => {
    let data = choiceData
    data[index] = value
    _setChoiceData(data)
    setData(data[0])
  }

  function getData() {
    const value = getInput().val();
    if (!value) return '';
    return value.split(',');
  }

  function setData(d) {
    getInput().val(JSON.stringify(d));
    setIsValid(Validation.isValid(
            req,
            input
        )
    )
  }

  function getInput() {
    return $(input);
  }

  if (!(Object.keys(choiceSet).length > 0)) {
    return ''
  }

  return (
      <div>
        <div key={choiceSet.fetchUrl} className="mb-1">
          <RenderChoiceSetInput
              locales={locales}
              fetchUrl={choiceSet.fetchUrl}
              selectedChoicesValue={choiceSet.selectedChoicesValue}
              getData={getData}
              setData={setData}
              setChoiceData={setChoiceData}
              index={0}
              choiceSet={choiceSet}
              fieldUuid={fieldUuid}
              getInput={getInput}
              req={req}
              input={input}
              componentPolicies={componentPolicies}
              isActive={isActive}
          />
        </div>
      </div>
  );
}

ChoiceSetInput.propTypes = {
  input: PropTypes.string.isRequired,
}

export default ChoiceSetInput;

const RenderChoiceSetInput = (props) => {
  const {
    locales,
    fetchUrl,
    selectedChoicesValue: selectedChoicesValueProps,
    setChoiceData,
    index,
    choiceSet,
    fieldUuid,
    getInput,
    req,
    input,
    componentPolicies,
    isActive
  } = props

  const [selectedChoices, setSelectedChoices] = useState({value: selectedChoicesValueProps})

  const [choices, setChoices] = useState([])
  const [loadingMessage, setLoadingMessage] = useState(Translations.messages['loading'])
  const [noOptionsMessage, setNoOptionsMessage] = useState(Translations.messages['no_options'])
  const [placeHolderMessage, setPlaceHolderMessage] = useState(Translations.messages['select_placeholder'])
  const [isInitialized, _setIsInitialized] = useState(false)
  const [optionsList, setOptionsList] = useState([])
  const [modalIndex, setModalIndex] = useState(1)
  const [modalOpen, setModalOpen] = useState(false)

  useEffect(() => {
    setModalIndex(modalIndex + 1)
  }, [selectedChoices])


  useEffect(() => {
    updateInputCategoryDataAttributes(choiceSet.selectedChoicesValue)
  }, [choiceSet])

  function updateChoiceData(arr) {
    if (Array.isArray(arr)) {
      setChoiceData(index, arr.map(i => i.toString()));
    } else {
      setChoiceData(index, [arr.toString()]);
    }
  }

  function _getJSONFilter(choice) {
    return {
      value: choice.id,
      label: choice.name,
      category_id: choice.category_id,
      id: choice.id,
      choice_set_id: choice.choice_set_id
    };
  }

  function updateInputCategoryDataAttributes(choices) {
    let form = getInput().parents('form:first')

    // Hide standard fields if they belong to a category
    form.find(`[data-field-category][data-field-category-choice-set-id=${choiceSet.id}]`)
        .parent(".form-group").hide()
    // Hide multilingual fields if they belong to a category
    form.find(`[data-field-category][data-field-category-choice-set-id=${choiceSet.id}]`)
        .parent(".input-group").parent(".form-group").parent(".form-group").hide()
    // Hide components if they belong to a category
    form.find(`[data-field-category][data-field-category-choice-set-id=${choiceSet.id}]`)
        .closest(".form-component").hide()

    if (choices && Array.isArray(choices)) {
      choices.forEach(choice => {
        // Show standard fields of the triggered category
        form.find(`[data-field-category=${choice.category_id}][data-field-category-choice-id=${choice.id}][data-field-category-choice-set-id=${choice.choice_set_id}]`)
            .parent(".form-group").show()
        // Show multilingual fields of the triggered category
        form.find(`[data-field-category=${choice.category_id}][data-field-category-choice-id=${choice.id}][data-field-category-choice-set-id=${choice.choice_set_id}]`)
            .parent(".input-group").parent(".form-group").parent(".form-group").show()
        // Show components of the triggered category
        form.find(`[data-field-category=${choice.category_id}][data-field-category-choice-id=${choice.id}][data-field-category-choice-set-id=${choice.choice_set_id}]`)
            .closest(".form-component").show()
      })
    }
  }

  function selectChoice(value) {
    setSelectedChoices({...selectedChoices, value: value});
    if (value?.length || value) {
      updateChoiceData(Array.isArray(value) ? value.map(v => v.value) : value.value)
      updateInputCategoryDataAttributes(Array.isArray(value) ? value : [value])
    } else {
      updateChoiceData([])
      updateInputCategoryDataAttributes()
    }
  }

  function _getFilterOptions(providedChoices = false) {
    let computedChoices = providedChoices ? providedChoices : choices
    computedChoices = computedChoices.map(choice =>
        _getJSONFilter(choice)
    );

    return computedChoices;
  }

  async function _loadOptions(search, loadedOptions, {page}) {
    // If the selected ChoiceSet is not active (deactivated
    // or deleted), then return an empty list of options.
    if (!isActive) {
      return {
        options: [],
        hasMore: false,
        additional: {
          page: page,
        },
      };
    }

    if (optionsList.length < 25 && isInitialized) {
      if (search.length > 0) {
        let regexExp = new RegExp(search, 'i')

        let choices = optionsList.filter(function (choice) {
          return choice.label !== null && choice.label.match(regexExp) !== null && choice.label.match(regexExp).length > 0
        });
        return {
          options: choices,
          hasMore: false,
          additional: {
            page: page + 1,
          },
        };
      }
      return {
        options: _getFilterOptions(),
        hasMore: choices.length === 25,
        additional: {
          page: page + 1,
        },
      };
    }

    const res = await axios.get(`${fetchUrl}&search=${search}&page=${page}`)

    if (!isInitialized) {
      setChoices(res.data.choices)
      setLoadingMessage(res.data.loading_message)
      setOptionsList(res.data.choices.map(choice => _getJSONFilter(choice)))

      return {
        options: _getFilterOptions(res.data.choices),
        hasMore: res.data.hasMore,
        additional: {
          page: page + 1,
        },
      };
    }
  }

  return (
      <div>
        <div className="choiceSetInput row d-flex">
          <div className="col-sm-8">
            <div className="choiceSetSelect"
                 style={Validation.getStyle(req, input)}>
              <AsyncPaginate
                  delimiter=","
                  loadOptions={_loadOptions}
                  debounceTimeout={800}
                  isSearchable={true}
                  isClearable={true}
                  isMulti={choiceSet.multiple}
                  loadingMessage={() => loadingMessage}
                  searchingMessage={() => loadingMessage}
                  placeholder={placeHolderMessage}
                  noOptionsMessage={() => noOptionsMessage}
                  additional={{
                    page: 1,
                  }}
                  styles={{menuPortal: base => ({...base, zIndex: 9999})}}
                  name="choices"
                  value={selectedChoices.value}
                  onChange={selectChoice}
                  options={optionsList}
              />
            </div>
          </div>
          {componentPolicies.modal && isActive && (
              <div className="col-sm-4">
                <a onClick={() => setModalOpen(true)} className="btn btn-sm btn-outline-secondary"
                   data-bs-toggle="modal"
                   data-bs-target={"#choice-modal-" + fieldUuid} href="#">
                  <i className="fa fa-plus"></i>
                </a>
              </div>
          )}
        </div>
        {(
            <ModalForm
                locales={locales}
                key={modalIndex}
                modalOpen={modalOpen}
                setModalOpen={setModalOpen}
                choiceSet={choiceSet}
                fieldUuid={fieldUuid}
                _getJSONFilter={_getJSONFilter}
                selectedChoices={selectedChoices}
                selectChoice={selectChoice}/>
        )}
      </div>
  )
}

const ModalForm = (props) => {
  const {
    locales,
    choiceSet,
    fieldUuid,
    _getJSONFilter,
    selectedChoices,
    selectChoice,
    modalOpen,
    setModalOpen
  } = props

  const [modalChoices, setModalChoices] = useState([])
  const [modalCategories, setModalCategories] = useState([])
  const [errorChoice, setErrorChoice] = useState('')
  const [selectedOption, setSelectedOption] = useState('');

  const handleOptionChange = (event) => {
    setSelectedOption(event.target.value);
  };

  useEffect(() => {
    if (modalOpen === true) {
      async function fetchData() {
        const response = await axios.get(choiceSet.newChoiceModalUrl)
        setModalChoices(response.data.choices)
        setModalCategories(response.data.categories)
      }

      fetchData()
    }

    // Cleanup
    return () => {
      setModalChoices([]);
      setModalCategories([]);
    };
  }, [modalOpen])


  const [errorMsg, setErrorMsg] = useState('')

  const handleSubmit = async (event) => {
    event.preventDefault();

    let form = event.target
    let params = '';
    for (let i = 0; i < form.elements.length; i++) {
      let fieldName = form.elements[i].name;
      let fieldValue = form.elements[i].value;

      params += fieldName + '=' + encodeURIComponent(fieldValue) + '&';
    }
    params += 'react' + '=' + 'true' + '&';

    try {
      axios.defaults.headers.common["X-CSRF-Token"] = (document.querySelector("meta[name=csrf-token]") || {}).content;
      axios.defaults.headers.common["X-Requested-With"] = 'XMLHttpRequest';
      axios.defaults.headers.common["content-type"] = 'application/x-www-form-urlencoded;charset=utf-8'
      const response = await axios.post(choiceSet.createChoiceUrl, params)

      if (response?.data?.choice_json_attributes) {
        if (choiceSet.multiple) {
          selectChoice([...selectedChoices.value || [], _getJSONFilter(response.data.choice_json_attributes)])
        } else {
          selectChoice([_getJSONFilter(response.data.choice_json_attributes)])
        }
        $(event.target).closest('div.modal').modal('hide')
        setErrorMsg('')
        setErrorChoice(false)
        setModalOpen(false)
      }
    } catch (error) {
      setErrorMsg(error.response?.data?.errors)
      setErrorChoice(error.response?.data?.choice)
    }
  }

  return (
      <div className="modal fade" id={"choice-modal-" + fieldUuid} tabIndex="-1" role="dialog"
           data-field-uuid={fieldUuid} data-lang="fr" aria-labelledby="myModalLabel">
        <div className="modal-dialog">
          <div className="modal-content">
            <form onSubmit={handleSubmit} id={`new_choice_${choiceSet.id}`}>
              <div className="modal-header">
                <h4 className="modal-title">{Translations.messages['catalog_admin.choice_sets.choice_modal.create_new_field']}</h4>
                <button type="button" className="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
              </div>
              <div className="modal-body">
                <div className="form-group mb-3">
                  <label className="form-label" htmlFor="choice_parent_id">Parent</label>
                  <select className="form-select" name="choice[parent_id]"
                          id="choice_parent_id">
                    <option value=""></option>
                    {modalChoices && modalChoices.map(o => {
                      return (
                          <option key={o.id} value={o.id}>{o.name}</option>
                      )
                    })
                    }
                  </select>
                </div>
                <div className="form-group mb-3">
                  <label className="form-label" htmlFor="choice_position">Position</label>
                  <select className="form-select" name="choice[position]"
                          id="choice_position">
                    <option
                        value="first">{Translations.messages['catalog_admin.choice_sets.choice_modal.position.first']}</option>
                    <option
                        value="last">{Translations.messages['catalog_admin.choice_sets.choice_modal.position.last']}</option>
                  </select>
                </div>

                <div className="mb-3 translatedTextField">
                  <label className="form-label"
                         htmlFor={`choice_short_name`}>{Translations.messages['catalog_admin.choices.choice_fields.short_name']}</label>
                  {
                    locales.map((locale, idx) => (
                        <div key={idx}>
                          <div className="form-group mb-3">
                            <label className="sr-only"
                                   htmlFor={`choice_short_name_${locale}`}>{Translations.messages['catalog_admin.choices.choice_fields.short_name']}</label>
                            <div className="input-group">
                              {locales.length > 1 && <span className="input-group-text">{locale}</span>}
                              <input className="form-control" type="text" name={`choice[short_name_${locale}]`}
                                     id={`choice_short_name_${locale}`}/>
                            </div>
                          </div>
                        </div>
                    ))
                  }
                </div>

                <div className="mb-3 translatedTextField">
                  <label className="form-label"
                         htmlFor={`choice_long_name`}>{Translations.messages['catalog_admin.choices.choice_fields.long_name_optional']}</label>
                  {
                    locales.map((locale, idx) => (
                        <div key={idx}>
                          <div className="form-group mb-3">
                            <label className="sr-only"
                                   htmlFor={`choice_long_name_${locale}`}>{Translations.messages['catalog_admin.choices.choice_fields.long_name_optional']}</label>
                            <div className="input-group">
                              {locales.length > 1 && <span className="input-group-text">{locale}</span>}
                              <input className="form-control" type="text" name={`choice[long_name_${locale}]`}
                                     id={`choice_long_name_${locale}`}/>
                            </div>
                          </div>
                        </div>
                    ))
                  }
                </div>

                <div className="form-group mb-3">
                  <label className="form-label"
                         htmlFor="choice_category_id">
                    {Translations.messages['catalog_admin.choices.choice_fields.category_optional']}
                  </label>
                  <select className="form-select"
                          name="choice[category_id]"
                          id="choice_category_id"
                          onChange={handleOptionChange}>
                    <option value="" label=""></option>
                    {modalCategories && modalCategories.map((category, idx) => (
                        <option key={idx} value={category[0]}>{category[1]}</option>
                    ))}
                  </select>
                </div>

                {selectedOption !== '' && <div
                    className="alert alert-danger">{Translations.messages['catalog_admin.choices.choice_fields.modal_category_alert']}</div>}

                <div className="base-errors">
                  {errorMsg}
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-outline-secondary"
                        data-bs-dismiss="modal">{Translations.messages["cancel"]}</button>
                <input type="submit" name="commit" value={Translations.messages["create"]}
                       className="btn btn-success"
                       data-disable-with={Translations.messages["create"]}/>
              </div>
            </form>
          </div>
        </div>
      </div>
  )
}
