// OfflinePOS Setup Wizard v11

const OfflinePOSWizard = {

    start: function () {

        const completed = localStorage.getItem("setup_completed");

        if (!completed) {
            this.showLanguageStep();
        }

    },


    showLanguageStep: function () {

        document.body.innerHTML += `

        <div id="wizardBox">

            <h2>Select Language / ژبه انتخاب کړئ</h2>

            <button onclick="OfflinePOSWizard.setLanguage('ps')">
            پښتو
            </button>

            <button onclick="OfflinePOSWizard.setLanguage('fa')">
            فارسی
            </button>

            <button onclick="OfflinePOSWizard.setLanguage('ur')">
            اردو
            </button>

            <button onclick="OfflinePOSWizard.setLanguage('en')">
            English
            </button>

            <button onclick="OfflinePOSWizard.setLanguage('ar')">
            العربية
            </button>

        </div>

        `;

    },


    setLanguage: function(lang){

        localStorage.setItem(
            "app_language",
            lang
        );

        this.showBusinessStep();

    },


    showBusinessStep:function(){

        document.getElementById("wizardBox").innerHTML = `

        <h2>Select Business Type</h2>

        <button onclick="OfflinePOSWizard.finish('retail')">
        Retail Store
        </button>


        <button onclick="OfflinePOSWizard.finish('hotel')">
        Hotel
        </button>


        <button onclick="OfflinePOSWizard.finish('restaurant')">
        Restaurant
        </button>


        <button onclick="OfflinePOSWizard.finish('pharmacy')">
        Pharmacy
        </button>


        <button onclick="OfflinePOSWizard.finish('sarafi')">
        Sarafi
        </button>


        <button onclick="OfflinePOSWizard.finish('realestate')">
        Real Estate
        </button>

        `;

    },


    finish:function(type){

        localStorage.setItem(
            "business_type",
            type
        );


        localStorage.setItem(
            "setup_completed",
            "true"
        );


        location.reload();

    }

};


window.onload=function(){

    OfflinePOSWizard.start();

};
