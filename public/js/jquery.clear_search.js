jQuery(document).ready(function() { 
	defaultValue = jQuery('#something').val();	
	jQuery('#something').click(function() { 
		if( this.value == defaultValue ) { 
			jQuery(this).val("");
		} 
	}); 
});