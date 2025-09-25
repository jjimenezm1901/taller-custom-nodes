import { IExecuteFunctions, INodeExecutionData, INodeType, INodeTypeDescription, NodeConnectionTypes, NodeOperationError } from 'n8n-workflow';

// Tipos para las reglas de ofuscación
interface ObfuscationRule {
    regex: string;
    method: string;
    replaceFirstN?: number;
    replaceLastN?: number;
    customReplacement?: string;
}

// Patrones predefinidos para diferentes tipos de datos sensibles
const PREDEFINED_PATTERNS: { [key: string]: string } = {
    'email': '\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b',
    'phone': '\\b(?:\\+?1[-.]?\\(?[0-9]{3}\\)?[-.]?[0-9]{3}[-.]?[0-9]{4}|\\+?51?\\s*\\d{9}|\\d{9}|\\d{10})\\b',
    'phone_international': '\\b\\+[1-9]\\d{1,14}\\b',
    'url': '\\bhttps?://[^\\s<>"{}|\\^`\\[\\]\\\\]+\\b',
    'credit_card': '\\b(?:\\d{4}[- ]?){3}\\d{4}\\b',
    'ssn': '\\b\\d{3}-\\d{2}-\\d{4}\\b',
    'dni': '\\b\\d{8}\\b',
    'passport': '\\b[A-Z]{1,2}\\d{6,9}\\b',
    'ip_address': '\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b',
    'mac_address': '\\b([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})\\b',
    'postal_code': '\\b\\d{5}(?:-\\d{4})?\\b',
    'date': '\\b\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}\\b',
    'time': '\\b\\d{1,2}:\\d{2}(?::\\d{2})?(?:\\s?[AP]M)?\\b',
    'currency': '\\b\\$\\d+(?:\\.\\d{2})?\\b',
    'percentage': '\\b\\d+(?:\\.\\d+)?%\\b',
    'custom_regex': ''
};

// Función para aplicar ofuscación
function applyObfuscation(data: any, rules: ObfuscationRule[]): any {
		//console.log("applyObfuscation");
		if (typeof data === 'string') {
			//console.log("data is a string");
        let result = data;
        for (const rule of rules) {
            try {
                const regex = new RegExp(rule.regex, 'g');
                result = result.replace(regex, (match) => {
									//console.log("match", match);
									//console.log("rule.method", rule.method);
									//console.log("rule.regex", rule.regex);
                    switch (rule.method) {
                        case 'replace_first_n':
                            if (rule.replaceFirstN && rule.replaceFirstN < match.length) {
                                return '*'.repeat(rule.replaceFirstN) + match.substring(rule.replaceFirstN);
                            }
                            return '*'.repeat(match.length);
                        case 'replace_last_n':
                            if (rule.replaceLastN && rule.replaceLastN < match.length) {
                                return match.substring(0, match.length - rule.replaceLastN) + '*'.repeat(rule.replaceLastN);
                            }
                            return '*'.repeat(match.length);
                        case 'asterisks':
                            return '*'.repeat(match.length);
                        case 'remove':
                            return '';
                        case 'numbers_to_letters':
                            return match.replace(/\d/g, (d) => String.fromCharCode(97 + parseInt(d)));
                        case 'letters_to_numbers':
                            return match.replace(/[a-zA-Z]/g, (c) => (c.charCodeAt(0) - 97).toString());
                        case 'custom_replacement':
                            return rule.customReplacement || '[REDACTED]';
                        case 'hash':
                            // Simple hash function without crypto module
                            let hash = 0;
                            for (let i = 0; i < match.length; i++) {
                                const char = match.charCodeAt(i);
                                hash = ((hash << 5) - hash) + char;
                                hash = hash & hash; // Convert to 32bit integer
                            }
                            return Math.abs(hash).toString(16).substring(0, 8);
                        case 'random_chars':
                            return Array.from({length: match.length}, () =>
                                'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'[Math.floor(Math.random() * 62)]
                            ).join('');
                        case 'category_label':
                            if (/\d{3}-\d{3}-\d{4}/.test(match)) return '[PHONE_NUMBER]';
                            if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(match)) return '[EMAIL]';
                            if (/\d{3}-\d{2}-\d{4}/.test(match)) return '[SSN]';
														if (/^\d{16}$/.test(match)) return '[CREDIT_CARD]';
														if (/^\d{10}$/.test(match)) return '[PHONE_NUMBER]';
														if (/^\d{8}$/.test(match)) return '[DOCUMENT_NUMBER]';
                            return '[SENSITIVE_DATA]';
                        default:
                            return '[REDACTED]';
                    }
                });
            } catch (error) {
                //console.warn(`Error applying regex rule: ${rule.regex}`, error);
            }
        }
				////console.log("result", result);
        return result;
    } else if (typeof data === 'object' && data !== null) {
				//console.log("data is an object");
        if (Array.isArray(data)) {
						//console.log("data is an array");
            return data.map(item => applyObfuscation(item, rules));
				} else {
						//console.log("data is an object2");
            const result: any = {};
            for (const [key, value] of Object.entries(data)) {
                result[key] = applyObfuscation(value, rules);
						}
						////console.log("result", result);
            return result;
        }
    }
    return data;
}

export class ObfuscationWrapper implements INodeType {

    description: INodeTypeDescription = {
        displayName: 'Data Obfuscation',
        name: 'obfuscationWrapper',
        icon: 'file:obfuscation-icon.svg',
        group: ['transform'],
        version: 1,
        subtitle: 'Obfuscates sensitive data in input',
        description: 'Applies obfuscation rules to sensitive data in the input and returns the obfuscated output.',
        defaults: {
            name: 'Data Obfuscation',
        },
        inputs: `={{
            ((parameters) => {
                const inputs = [];

                if (parameters?.operationMode !== 'simple_tool' && parameters?.operationMode !== 'tool_wrapper') {
                    inputs.push({
                        displayName: "Main",
                        type: "${NodeConnectionTypes.Main}",
                        required: true,
                        maxConnections: 1
                    });
                }

                return inputs;
            })($parameter)
        }}`,
        outputs: `={{
            ((parameters) => {
                const outputs = [];
                    outputs.push({
                        displayName: "Main",
                        type: "${NodeConnectionTypes.Main}",
                        required: true,
                        maxConnections: 1
                    });
                return outputs;
            })($parameter)
        }}`,
        usableAsTool: true,
        properties: [
            {
                displayName: 'Enable Image Filtering',
                name: 'enableImageFiltering',
                type: 'boolean',
                default: true,
                description: 'Whether to filter out images from data to reduce log size',
            },
            {
                displayName: 'Operation Mode',
                name: 'operationMode',
                type: 'options',
                options: [
                    {
                        name: 'Simple Node',
                        value: 'simple',
                        description: 'Simple node that obfuscates input and returns obfuscated output'
                    }
                ],
                default: 'simple',
                description: 'How the node should operate',
            },
            {
                displayName: 'Obfuscation Rules',
                name: 'obfuscationRules',
                type: 'fixedCollection',
                typeOptions: {
                    multipleValues: true,
                },
                default: {},
                description: 'Rules to obfuscate sensitive data in subnode outputs',
                options: [
                    {
                        displayName: 'Rules',
                        name: 'rules',
                        values: [
                            {
                                displayName: 'Custom Regex Pattern',
                                name: 'customRegex',
                                type: 'string',
                                default: '',
                                description: 'Custom regular expression pattern (only used when Data Type is Custom Regex)',
                                placeholder: '\\b\\d{3}-\\d{3}-\\d{4}\\b',
                                displayOptions: {
                                    show: {
                                        dataType: ['custom_regex'],
                                    },
                                },
                            },
                            {
                                displayName: 'Custom Replacement',
                                name: 'customReplacement',
                                type: 'string',
                                default: '[REDACTED]',
                                description: 'Custom string to replace matched data',
                                displayOptions: {
                                    show: {
                                        method: ['custom_replacement'],
                                    },
                                },
                            },
                            {
                                displayName: 'Data Type',
                                name: 'dataType',
                                type: 'options',
                                options: [
                                    { name: 'Credit Card Number', value: 'credit_card' },
                                    { name: 'Currency Amount', value: 'currency' },
                                    { name: 'Custom Regex', value: 'custom_regex' },
                                    { name: 'Date', value: 'date' },
                                    { name: 'DNI / National ID', value: 'dni' },
                                    { name: 'Email Address', value: 'email' },
                                    { name: 'IP Address', value: 'ip_address' },
                                    { name: 'MAC Address', value: 'mac_address' },
                                    { name: 'Passport Number', value: 'passport' },
                                    { name: 'Percentage', value: 'percentage' },
                                    { name: 'Phone Number', value: 'phone' },
                                    { name: 'Phone Number (International)', value: 'phone_international' },
                                    { name: 'Postal Code', value: 'postal_code' },
                                    { name: 'Social Security Number (SSN)', value: 'ssn' },
                                    { name: 'Time', value: 'time' },
                                    { name: 'URL', value: 'url' },
                                ],
                                default: 'email',
                                description: 'Type of sensitive data to detect',
                            },
                            {
                                displayName: 'Obfuscation Method',
                                name: 'method',
                                type: 'options',
                                options: [
                                    { name: 'Category Label', value: 'category_label' },
                                    { name: 'Custom Replacement', value: 'custom_replacement' },
                                    { name: 'Hash (SHA-256)', value: 'hash' },
                                    { name: 'Letters to Numbers', value: 'letters_to_numbers' },
                                    { name: 'Numbers to Letters', value: 'numbers_to_letters' },
                                    { name: 'Random Characters', value: 'random_chars' },
                                    { name: 'Remove Completely', value: 'remove' },
                                    { name: 'Replace [All] With Asterisks', value: 'asterisks' },
                                    { name: 'Replace [First N] Characters (*)', value: 'replace_first_n' },
                                    { name: 'Replace [Last N] Characters (*)', value: 'replace_last_n' },
                                ],
                                default: 'asterisks',
                                description: 'Method to obfuscate matched data',
                            },
                            {
                                displayName: 'Replace First N',
                                name: 'replaceFirstN',
                                type: 'number',
                                default: 3,
                                description: 'Number of characters to replace from the beginning',
                                displayOptions: {
                                    show: {
                                        method: ['replace_first_n'],
                                    },
                                },
                            },
                            {
                                displayName: 'Replace Last N',
                                name: 'replaceLastN',
                                type: 'number',
                                default: 3,
                                description: 'Number of characters to replace from the end',
                                displayOptions: {
                                    show: {
                                        method: ['replace_last_n'],
                                    },
                                },
                            },
                        ],
                    },
                ],
            }
        ],
    };

    async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
        try {
            // Obtener parámetros del nodo
            const operationMode = this.getNodeParameter('operationMode', 0, 'simple') as string;
            // const enableLogSilencing = this.getNodeParameter('enableLogSilencing', 0, true) as boolean;
            const enableImageFiltering = this.getNodeParameter('enableImageFiltering', 0, true) as boolean;
            const obfuscationRulesData = this.getNodeParameter('obfuscationRules', 0, {}) as any;

            // Procesar reglas de ofuscación
            const obfuscationRules: ObfuscationRule[] = [];
            if (obfuscationRulesData.rules && Array.isArray(obfuscationRulesData.rules)) {
                for (const rule of obfuscationRulesData.rules) {
                    let regexPattern = '';

                    if (rule.dataType === 'custom_regex') {
                        regexPattern = rule.customRegex || '';
                    } else {
                        regexPattern = PREDEFINED_PATTERNS[rule.dataType] || '';
                    }

                    if (regexPattern) {
                        obfuscationRules.push({
                            regex: regexPattern,
                            method: rule.method,
                            replaceFirstN: rule.replaceFirstN,
                            replaceLastN: rule.replaceLastN,
                            customReplacement: rule.customReplacement,
                        });
                    }
                }
            }

            // Función de ofuscación para outputs de subnodos
            const obfuscateSubnodeOutput = (data: any) => {
                if (!enableImageFiltering && typeof data === 'string' &&
                    (data.startsWith('data:image/') || data.includes('image/'))) {
                    return '[IMAGE_REDACTED]';
                }

                if (obfuscationRules.length > 0) {
                    return applyObfuscation(data, obfuscationRules);
                }

                return data;
            };

            try {
                if (operationMode === 'simple') {
                    // MODO SIMPLE: Procesar input principal y ofuscar
                    const mainInput = this.getInputData(0);
                    if (mainInput.length === 0) {
                        return this.prepareOutputData([]);
                    }

                    const processedData = mainInput.map(item => ({
                        ...item,
                        json: obfuscateSubnodeOutput(item.json),
                        binary: item.binary ? Object.keys(item.binary).reduce((acc, key) => {
                            acc[key] = {
                                ...item.binary![key],
                                data: enableImageFiltering && item.binary![key].mimeType?.startsWith('image/')
                                    ? '[IMAGE_REDACTED]'
                                    : item.binary![key].data
                            };
                            return acc;
                        }, {} as any) : undefined
                    }));

                    // Preparar datos de salida
                    const outputData = processedData;

                    return this.prepareOutputData(outputData);

                                // } else if (operationMode === 'wrapper') {
                //     // MODO WRAPPER: Solo procesar outputs de subnodos (tools)
                //     const processedOutputs: INodeExecutionData[] = [];
                } else {
                    // Caso por defecto: procesar input principal sin ofuscación especial
                    const mainInput = this.getInputData(0);
                    if (mainInput.length === 0) {
                        return this.prepareOutputData([]);
                    }
                    return this.prepareOutputData(mainInput);
                }

            } finally {
                // Los logs se restauran automáticamente al final de la ejecución
            }

        } catch (error) {
            throw new NodeOperationError(this.getNode(), `Error en ObfuscationWrapper: ${error}`);
        }
    }
}
