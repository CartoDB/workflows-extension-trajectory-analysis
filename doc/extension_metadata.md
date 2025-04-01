# Extension metadata
Here you can find a reference of the different properties that must be contained in the metadata object of the extension.

This is the expected structure of the metadata file:
```json
{
    "name": "extension_name",
    "title": "Extension title",
    "industry": "Industry",
    "description": "Extension description",
    "icon": "extension_icon.svg",
    "version": "1.0.1",
    "author": {
        "value": "Author name",
        "link": {
            "label": "Author name",
            "href": "https://author_url/"
        }
    },
    "license": {
        "value": "Author license",
        "link": {
            "label": "Author name",
            "href": "https://author_url/"
        }
    },
    "lastUpdate": "Dec 21, 2024", 
    "provider": "bigquery | snowflake",
    "details": [
        {
            "name": "Optional detail 1",
            "value": "Optional detail value",
            "link": {
                "label": "Optional detail value",
                "href": "https://optional_detail_url/"
            }
        },
        {
            "name": "Optional detail 2",
            "value": "Optional detail value",
            "link": {
                "label": "Optional detail value",
                "href": "https://optional_detail_url/"
            }
        }
    ],
    "components": [
        "component_1",
        "component_2",
        "component_3",
        "component_4",
        ...
    ]
}
```

Some important notes:
* All elements are mandatory except for the `details` array, wich can be empty. 
* The `author` and `license` objects can be rendered as a link or a string. If the `link` property is not provided, the `value` property will be rendered as a string.
* The `icon` property must be the name of a valid SVG file in the `icons` folder.
* It's important to specify which data warehouse is compatible with your extension. For this, the `"provider"` property needs to be set to either `"bigquery"` or `"snowflake"`.
* Each element in the `details` array will be rendered in the extension's details page. Provide either a `link` or a `value` property. If both are provided, the `link` property will be rendered as a link and the `value` property will be ignored.
* The `components` object must contain an array of all the components included in the extension.